import AppKit
import Foundation
import SwiftUI

package enum CosmoTextClassifier {
    package static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2CEAF,
                 0x2F800...0x2FA1F:
                true
            default:
                false
            }
        }
    }
}

enum CosmoTypography {
    enum Role {
        case display
        case body
        case ui
        case mono
    }

    static let songtiFamily = "Songti SC"
    static let uiFamily = "PingFang SC"

    static func font(
        for text: String,
        role: Role = .body,
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        switch role {
        case .display:
            if CosmoTextClassifier.containsChinese(text) {
                return Font.custom(songtiFamily, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .serif)
        case .body:
            if CosmoTextClassifier.containsChinese(text) {
                return Font.custom(uiFamily, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: design)
        case .ui:
            if CosmoTextClassifier.containsChinese(text) {
                return Font.custom(uiFamily, size: size).weight(weight)
            }
            let resolvedDesign: Font.Design = design == .default ? .rounded : design
            return .system(size: size, weight: weight, design: resolvedDesign)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }

    static func songti(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(songtiFamily, size: size).weight(weight)
    }
}

extension Text {
    func cosmoTextFont(
        _ sample: String,
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Text {
        font(CosmoTypography.font(for: sample, role: .body, size: size, weight: weight, design: design))
    }

    func cosmoDisplayFont(
        _ sample: String,
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Text {
        font(CosmoTypography.font(for: sample, role: .display, size: size, weight: weight))
    }

    func cosmoUIFont(
        _ sample: String,
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Text {
        font(CosmoTypography.font(for: sample, role: .ui, size: size, weight: weight, design: design))
    }
}

extension View {
    func cosmoInputFont(size: CGFloat = 15) -> some View {
        font(CosmoTypography.font(for: "Input", role: .ui, size: size))
    }

    func cosmoMonoFont(size: CGFloat = 13, weight: Font.Weight = .regular) -> some View {
        font(CosmoTypography.font(for: "Mono", role: .mono, size: size, weight: weight))
    }
}

package enum SiteIconResolver {
    package static func normalizedHost(from urlString: String) -> String? {
        guard
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host?.lowercased(),
            !host.isEmpty
        else {
            return nil
        }

        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    package static func fallbackIconURL(for host: String) -> URL? {
        URL(string: "https://\(host)/favicon.ico")
    }
}

@MainActor
final class SiteIconService {
    static let shared = SiteIconService()

    private var imageCache: [String: NSImage] = [:]
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let supportDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let appSupport = supportDirectory.appendingPathComponent("Cosmogony", isDirectory: true)
        cacheDirectory = appSupport.appendingPathComponent("Favicons", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func icon(for urlString: String) async -> NSImage? {
        guard let host = SiteIconResolver.normalizedHost(from: urlString) else {
            return nil
        }

        if let image = imageCache[host] {
            return image
        }

        if let image = loadCachedIcon(for: host) {
            imageCache[host] = image
            return image
        }

        guard let pageURL = URL(string: urlString) else {
            return nil
        }

        if let image = await fetchIconFromDeclaredLinks(pageURL: pageURL, host: host) {
            imageCache[host] = image
            return image
        }

        if let fallbackURL = SiteIconResolver.fallbackIconURL(for: host),
           let image = await fetchIcon(from: fallbackURL, host: host) {
            imageCache[host] = image
            return image
        }

        return nil
    }

    private func loadCachedIcon(for host: String) -> NSImage? {
        let url = cacheURL(for: host)
        guard
            let data = try? Data(contentsOf: url),
            let image = NSImage(data: data)
        else {
            return nil
        }
        return image
    }

    private func fetchIconFromDeclaredLinks(pageURL: URL, host: String) async -> NSImage? {
        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 6

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }

            let html = String(decoding: data, as: UTF8.self)
            for candidate in iconCandidates(in: html, relativeTo: pageURL) {
                if let image = await fetchIcon(from: candidate, host: host) {
                    return image
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func fetchIcon(from url: URL, host: String) async -> NSImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard let image = NSImage(data: data) else {
                return nil
            }
            try? data.write(to: cacheURL(for: host), options: .atomic)
            return image
        } catch {
            return nil
        }
    }

    private func iconCandidates(in html: String, relativeTo baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        var seen = Set<String>()

        for tag in matches(in: html, pattern: #"(?is)<link\b[^>]*>"#) {
            guard
                let rel = capture(in: tag, pattern: #"rel\s*=\s*["']([^"']+)["']"#),
                rel.localizedCaseInsensitiveContains("icon"),
                let href = capture(in: tag, pattern: #"href\s*=\s*["']([^"']+)["']"#),
                let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL
            else {
                continue
            }

            if seen.insert(resolved.absoluteString).inserted {
                candidates.append(resolved)
            }
        }

        return candidates
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else {
                return nil
            }
            return String(text[matchRange])
        }
    }

    private func capture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[valueRange])
    }

    private func cacheURL(for host: String) -> URL {
        let safeHost = host.replacingOccurrences(of: #"[^A-Za-z0-9._-]"#, with: "_", options: .regularExpression)
        return cacheDirectory.appendingPathComponent("\(safeHost).img", isDirectory: false)
    }
}

@MainActor
final class SiteIconViewModel: ObservableObject {
    @Published private(set) var image: NSImage?

    private let urlString: String

    init(urlString: String) {
        self.urlString = urlString
    }

    func loadIfNeeded() async {
        guard image == nil else { return }
        image = await SiteIconService.shared.icon(for: urlString)
    }
}
