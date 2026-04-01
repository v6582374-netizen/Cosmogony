import AppKit
import Carbon
import Foundation
import Network

struct BrowserPageContext: Sendable {
    var browserName: String
    var url: String
    var title: String
}

struct BridgeHandshakeRequest: Codable, Sendable {
    var extensionID: String
    var version: String
}

struct BridgeHandshakeResponse: Codable, Sendable {
    var token: String
    var accepted: Bool
}

struct BridgePageCapturePayload: Codable, Sendable {
    var url: String
    var title: String
    var selection: String
    var content: String
    var excerpt: String
    var browserName: String
}

struct BridgeClipboardCapturePayload: Codable, Sendable {
    var text: String
    var sourceApplication: String?
}

struct ProviderProbeResult: Sendable {
    var success: Bool
    var message: String
    var resolvedURL: String
}

enum CaptureError: LocalizedError {
    case unsupportedBrowser
    case noFrontmostPage
    case emptyClipboard

    var errorDescription: String? {
        switch self {
        case .unsupportedBrowser:
            "当前前台应用不是受支持的 Chromium 浏览器。"
        case .noFrontmostPage:
            "无法读取当前活动标签页。请确认浏览器已授权 Apple Events。"
        case .emptyClipboard:
            "剪贴板当前没有文本内容。"
        }
    }
}

final class ChromiumBrowserProbe {
    private let supportedApps: [(name: String, bundleIDs: Set<String>)] = [
        ("Google Chrome", ["com.google.Chrome"]),
        ("Arc", ["company.thebrowser.Browser"]),
        ("Microsoft Edge", ["com.microsoft.edgemac"]),
        ("Brave Browser", ["com.brave.Browser"])
    ]

    func captureFrontmostPage() throws -> BrowserPageContext {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.noFrontmostPage
        }

        guard let matched = supportedApps.first(where: { $0.bundleIDs.contains(app.bundleIdentifier ?? "") || $0.name == app.localizedName }) else {
            throw CaptureError.unsupportedBrowser
        }

        let script = """
        tell application "\(matched.name)"
            if (count of windows) is 0 then error "No window"
            set theTab to active tab of front window
            return (URL of theTab) & linefeed & (title of theTab)
        end tell
        """

        let output = try runAppleScript(script)
        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 2 else {
            throw CaptureError.noFrontmostPage
        }

        return BrowserPageContext(browserName: matched.name, url: parts[0], title: parts[1])
    }

    private func runAppleScript(_ source: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            throw NSError(domain: "Cosmogony.BrowserProbe", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: String(decoding: errData, as: UTF8.self)
            ])
        }

        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class PasteboardCaptureService {
    func capture() throws -> BridgeClipboardCapturePayload {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw CaptureError.emptyClipboard
        }

        return BridgeClipboardCapturePayload(
            text: text,
            sourceApplication: NSWorkspace.shared.frontmostApplication?.localizedName
        )
    }
}

struct ContentEnricher: Sendable {
    func enrich(from urlString: String, maxLength: Int) async -> (excerpt: String, content: String) {
        guard let url = URL(string: urlString) else {
            return ("", "")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(decoding: data, as: UTF8.self)
            let plainText = stripHTML(html).prefix(maxLength)
            let content = String(plainText)
            return (compactSummary(from: content), content)
        } catch {
            return ("", "")
        }
    }

    private func stripHTML(_ input: String) -> String {
        var output = input.replacingOccurrences(of: "(?is)<script.*?</script>", with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: "(?is)<style.*?</style>", with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: "(?is)<[^>]+>", with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: "&nbsp;", with: " ")
        output = output.replacingOccurrences(of: "&amp;", with: "&")
        output = output.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ProviderProbeService: Sendable {
    func probe(profile: ProviderProfile, apiKey: String) async -> ProviderProbeResult {
        let secret = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else {
            return ProviderProbeResult(success: false, message: "Missing API key.", resolvedURL: profile.resolvedBaseURL)
        }

        let baseURL = profile.resolvedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty else {
            return ProviderProbeResult(success: false, message: "Missing base URL.", resolvedURL: "")
        }

        guard let request = buildRequest(profile: profile, apiKey: secret) else {
            return ProviderProbeResult(success: false, message: "Invalid provider URL.", resolvedURL: baseURL)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ProviderProbeResult(success: false, message: "No HTTP response.", resolvedURL: request.url?.absoluteString ?? baseURL)
            }

            if (200..<300).contains(http.statusCode) {
                return ProviderProbeResult(
                    success: true,
                    message: "Connection verified with status \(http.statusCode).",
                    resolvedURL: request.url?.absoluteString ?? baseURL
                )
            }

            let body = String(decoding: data.prefix(240), as: UTF8.self).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let message = body.isEmpty ? "Request failed with status \(http.statusCode)." : "Status \(http.statusCode): \(body)"
            return ProviderProbeResult(success: false, message: message, resolvedURL: request.url?.absoluteString ?? baseURL)
        } catch {
            return ProviderProbeResult(success: false, message: error.localizedDescription, resolvedURL: request.url?.absoluteString ?? baseURL)
        }
    }

    private func buildRequest(profile: ProviderProfile, apiKey: String) -> URLRequest? {
        let trimmedBaseURL = profile.resolvedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let requestURLString: String

        switch profile.kind {
        case .gemini:
            requestURLString = "\(trimmedBaseURL)/v1beta/models?key=\(apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey)"
        case .claude:
            requestURLString = "\(trimmedBaseURL)/v1/models"
        case .openAI, .deepseek, .minimax, .openAICompatible:
            requestURLString = "\(trimmedBaseURL)/v1/models"
        }

        guard let url = URL(string: requestURLString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = "GET"

        switch profile.kind {
        case .claude:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini:
            break
        case .openAI, .deepseek, .minimax, .openAICompatible:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

final class LocalBridgeServer: @unchecked Sendable {
    var onHandshake: (() -> String)?
    var currentToken: (() -> String?)?
    var onPageCapture: ((BridgePageCapturePayload) -> Void)?
    var onClipboardCapture: ((BridgeClipboardCapturePayload) -> Void)?

    private let queue = DispatchQueue(label: "cosmogony.bridge")
    private var listener: NWListener?
    private(set) var port: UInt16 = 17832

    func start() throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: .tcp, on: .init(integerLiteral: port))
        listener.newConnectionHandler = { [weak self] connection in
            self?.receive(on: connection, buffer: Data())
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 262_144) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let request = self.parseRequest(from: nextBuffer) {
                let response = self.handle(request: request)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            if error != nil || isComplete {
                let response = self.httpResponse(status: "400 Bad Request", json: #"{"error":"invalid_request"}"#)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            self.receive(on: connection, buffer: nextBuffer)
        }
    }

    private struct HTTPRequest {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data
    }

    private func parseRequest(from data: Data) -> HTTPRequest? {
        guard let text = String(data: data, encoding: .utf8),
              let range = text.range(of: "\r\n\r\n") else {
            return nil
        }

        let headerText = String(text[..<range.lowerBound])
        let headerLines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let segments = line.split(separator: ":", maxSplits: 1).map(String.init)
            if segments.count == 2 {
                headers[segments[0].trimmingCharacters(in: .whitespaces).lowercased()] = segments[1].trimmingCharacters(in: .whitespaces)
            }
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = text.distance(from: text.startIndex, to: range.upperBound)
        let bodyData = data.dropFirst(bodyStart)
        guard bodyData.count >= contentLength else {
            return nil
        }

        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            body: Data(bodyData.prefix(contentLength))
        )
    }

    private func handle(request: HTTPRequest) -> Data {
        switch (request.method, request.path) {
        case ("GET", "/v1/health"):
            return httpResponse(status: "200 OK", json: #"{"status":"ok"}"#)

        case ("POST", "/v1/handshake"):
            guard let onHandshake,
                  let body = try? JSONDecoder().decode(BridgeHandshakeRequest.self, from: request.body)
            else {
                return httpResponse(status: "400 Bad Request", json: #"{"error":"invalid_handshake"}"#)
            }
            let token = onHandshake()
            let response = BridgeHandshakeResponse(token: token, accepted: !body.extensionID.isEmpty)
            guard let data = try? JSONEncoder().encode(response),
                  let json = String(data: data, encoding: .utf8) else {
                return httpResponse(status: "500 Internal Server Error", json: #"{"error":"encode_failed"}"#)
            }
            return httpResponse(status: "200 OK", json: json)

        case ("POST", "/v1/captures/page"):
            guard authorize(request.headers) else {
                return httpResponse(status: "401 Unauthorized", json: #"{"error":"unauthorized"}"#)
            }
            guard let payload = try? JSONDecoder().decode(BridgePageCapturePayload.self, from: request.body) else {
                return httpResponse(status: "400 Bad Request", json: #"{"error":"invalid_payload"}"#)
            }
            Task { @MainActor in
                self.onPageCapture?(payload)
            }
            return httpResponse(status: "202 Accepted", json: #"{"accepted":true}"#)

        case ("POST", "/v1/captures/clipboard"):
            guard authorize(request.headers) else {
                return httpResponse(status: "401 Unauthorized", json: #"{"error":"unauthorized"}"#)
            }
            guard let payload = try? JSONDecoder().decode(BridgeClipboardCapturePayload.self, from: request.body) else {
                return httpResponse(status: "400 Bad Request", json: #"{"error":"invalid_payload"}"#)
            }
            Task { @MainActor in
                self.onClipboardCapture?(payload)
            }
            return httpResponse(status: "202 Accepted", json: #"{"accepted":true}"#)

        default:
            return httpResponse(status: "404 Not Found", json: #"{"error":"not_found"}"#)
        }
    }

    private func authorize(_ headers: [String: String]) -> Bool {
        let incoming = headers["x-cosmogony-token"]
        return !((currentToken?() ?? "").isEmpty) && incoming == currentToken?()
    }

    private func httpResponse(status: String, json: String) -> Data {
        let contentLength = json.lengthOfBytes(using: .utf8)
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: application/json\r
        Content-Length: \(contentLength)\r
        Connection: close\r
        \r
        \(json)
        """
        return Data(response.utf8)
    }
}

final class HotKeyCenter {
    typealias Handler = () -> Void

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: Handler] = [:]

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                center.handlers[hotKeyID.id]?()
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        unregisterAll()
    }

    func register(settings: ShortcutSettings, onCapturePage: @escaping Handler, onCaptureClipboard: @escaping Handler) {
        unregisterAll()
        handlers[1] = onCapturePage
        handlers[2] = onCaptureClipboard
        hotKeys[1] = register(key: settings.captureCurrentPage, id: 1)
        hotKeys[2] = register(key: settings.captureClipboard, id: 2)
    }

    private func register(key: KeyCombination, id: UInt32) -> EventHotKeyRef? {
        let hotKeyID = EventHotKeyID(signature: OSType(0x43534D47), id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(key.keyCode, key.carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        return ref
    }

    private func unregisterAll() {
        for (_, ref) in hotKeys {
            UnregisterEventHotKey(ref)
        }
        hotKeys.removeAll()
        handlers.removeAll()
    }
}
