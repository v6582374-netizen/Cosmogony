import AppKit
import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published public var settings: AppSettings
    @Published public var providerProfiles: [ProviderProfile]
    @Published public var providerSecrets: [String: String]
    @Published public var categoryRules: [CategoryRule]
    @Published public var clips: [ClipItem] = []
    @Published public var selectedScope: ClipScope = .library
    @Published public var selectedPlatform: PlatformFilter = .all
    @Published public var timeboxDraft = TimeboxDraft()
    @Published public var searchText = ""
    @Published public var selectedClipID: String?
    @Published public var statusMessage = "Ready."
    @Published public var bridgeStatus = "Bridge offline"
    @Published public var shortcutConflict: String?
    @Published public var stats = ClipStats()
    @Published public var providerProbeMessages: [String: String] = [:]
    @Published public var providerProbeRunning = Set<String>()

    let database: AppDatabase
    private let keychain = KeychainStore()
    private let browserProbe = ChromiumBrowserProbe()
    private let pasteboardCapture = PasteboardCaptureService()
    private let enricher = ContentEnricher()
    private let bridge = LocalBridgeServer()
    private let hotKeys = HotKeyCenter()
    private let launchAtLogin = LaunchAtLoginController()
    private let providerProbe = ProviderProbeService()
    private let keychainService = "Cosmogony.ProviderSecrets"

    public static func bootstrap() -> AppModel {
        do {
            return try AppModel()
        } catch {
            fatalError("Cosmogony bootstrap failed: \(error)")
        }
    }

    public init() throws {
        database = try AppDatabase()
        settings = try database.fetchSettings()
        providerProfiles = try database.fetchProviderProfiles()
        categoryRules = try database.fetchCategoryRules()
        providerSecrets = [:]

        for profile in providerProfiles {
            providerSecrets[profile.id] = keychain.loadString(service: keychainService, account: profile.apiKeyRef)
        }

        refreshLaunchAtLoginFlag()
        configureBridge()
        rebindHotKeys()
        try bridge.start()
        bridgeStatus = "Bridge listening on 127.0.0.1:\(bridge.port)"
        try reloadClips()
        try reloadStats()
    }

    public var selectedClip: ClipItem? {
        guard let selectedClipID else { return nil }
        return clips.first(where: { $0.id == selectedClipID })
    }

    public var searchMode: SearchMode {
        SearchScorer.mode(settings: settings, profiles: providerProfiles)
    }

    public func reloadClips() throws {
        clips = try database.fetchClips(
            scope: selectedScope,
            platformFilter: selectedPlatform,
            timebox: timeboxDraft.filter,
            search: searchText,
            settings: settings,
            profiles: providerProfiles
        )

        if selectedClip == nil {
            selectedClipID = clips.first?.id
        }
    }

    public func reloadStats() throws {
        stats = try database.fetchStats(timebox: timeboxDraft.filter)
    }

    public func refreshFilters() {
        do {
            try reloadClips()
            try reloadStats()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func captureCurrentPage() {
        do {
            let context = try browserProbe.captureFrontmostPage()
            ingestCurrentPage(url: context.url, title: context.title, browserName: context.browserName, excerpt: "", content: "")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func captureClipboard() {
        do {
            let payload = try pasteboardCapture.capture()
            ingestClipboard(payload)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func ingestPagePayload(_ payload: BridgePageCapturePayload) {
        ingestCurrentPage(
            url: payload.url,
            title: payload.title,
            browserName: payload.browserName,
            excerpt: payload.excerpt.isEmpty ? compactSummary(from: payload.selection.isEmpty ? payload.content : payload.selection) : payload.excerpt,
            content: payload.selection.isEmpty ? payload.content : payload.selection + "\n\n" + payload.content
        )
    }

    func ingestClipboard(_ payload: BridgeClipboardCapturePayload) {
        let now = Date()
        let rawText = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawText.count > 72 ? String(rawText.prefix(72)) + "..." : rawText
        let url = URL(string: rawText)?.absoluteString ?? "clipboard://local"
        var clip = ClipItem(
            sourceType: .clipboard,
            url: url,
            title: title,
            domain: payload.sourceApplication ?? "Clipboard",
            platformBucket: URL(string: rawText) == nil ? .otherWeb : PlatformClassifier.bucket(for: rawText),
            capturedAt: now,
            capturedHourBucket: floorToHour(now),
            excerpt: compactSummary(from: rawText),
            content: String(rawText.prefix(settings.capture.maxStoredCharacters)),
            aiSummary: compactSummary(from: rawText),
            category: payload.sourceApplication ?? "Clipboard",
            tags: [],
            note: "",
            status: .inbox
        )
        clip.refreshSearchText()
        persist(clip)
        statusMessage = "Captured clipboard content."
    }

    private func ingestCurrentPage(url: String, title: String, browserName: String, excerpt: String, content: String) {
        let now = Date()
        let domain = normalizedDomain(from: url)
        let bucket = PlatformClassifier.bucket(for: url)
        let seedContent = String(content.prefix(settings.capture.maxStoredCharacters))
        let seedExcerpt = excerpt.isEmpty ? compactSummary(from: seedContent) : excerpt

        var clip = ClipItem(
            sourceType: .webPage,
            url: url,
            title: title,
            domain: domain.isEmpty ? browserName : domain,
            platformBucket: bucket,
            capturedAt: now,
            capturedHourBucket: floorToHour(now),
            excerpt: seedExcerpt,
            content: seedContent,
            aiSummary: compactSummary(from: seedExcerpt.isEmpty ? title : seedExcerpt),
            category: categorySuggestion(for: bucket, domain: domain),
            tags: [],
            note: "",
            status: .inbox
        )
        clip.refreshSearchText()
        persist(clip)
        statusMessage = "Captured \(title)."

        guard settings.capture.enrichPublicPages, content.isEmpty else { return }
        Task {
            let enrichment = await enricher.enrich(from: url, maxLength: settings.capture.maxStoredCharacters)
            await MainActor.run {
                self.applyEnrichment(for: clip.id, excerpt: enrichment.excerpt, content: enrichment.content)
            }
        }
    }

    private func applyEnrichment(for id: String, excerpt: String, content: String) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            if !excerpt.isEmpty {
                clip.excerpt = excerpt
            }
            if !content.isEmpty {
                clip.content = content
            }
            clip.aiSummary = compactSummary(from: !content.isEmpty ? content : clip.excerpt)
            clip.status = .library
            clip.refreshSearchText()
            try database.saveClip(clip)
            try reloadClips()
        } catch {
            statusMessage = "Enrichment failed: \(error.localizedDescription)"
        }
    }

    private func persist(_ clip: ClipItem) {
        do {
            try database.saveClip(clip)
            try reloadClips()
            try reloadStats()
            selectedClipID = clip.id
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func saveClipEdits(
        id: String,
        category: String,
        tagsText: String,
        note: String,
        status: ClipStatus
    ) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            clip.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
            clip.tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            clip.note = note
            clip.status = status
            clip.refreshSearchText()
            try database.saveClip(clip)
            try reloadClips()
            try reloadStats()
            statusMessage = "Clip updated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func addProviderProfile() {
        var profile = ProviderProfile()
        profile.displayName = "Provider \(providerProfiles.count + 1)"
        profile.baseURL = profile.kind.suggestedBaseURL
        saveProviderProfile(profile)
    }

    public func saveProviderProfile(_ profile: ProviderProfile) {
        do {
            try database.saveProviderProfile(profile)
            providerProfiles = try database.fetchProviderProfiles()
            if providerSecrets[profile.id] == nil {
                providerSecrets[profile.id] = ""
            }

            if settings.defaultReasoningProfileID == nil {
                settings.defaultReasoningProfileID = profile.id
            }
            if settings.defaultEmbeddingProfileID == nil && profile.supportsEmbeddings {
                settings.defaultEmbeddingProfileID = profile.id
            }
            try persistSettings()
            statusMessage = "Provider profile saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteProviderProfile(_ profile: ProviderProfile) {
        do {
            try database.deleteProviderProfile(id: profile.id)
            keychain.deleteString(service: keychainService, account: profile.apiKeyRef)
            providerProfiles = try database.fetchProviderProfiles()
            providerSecrets[profile.id] = nil
            if settings.defaultReasoningProfileID == profile.id {
                settings.defaultReasoningProfileID = providerProfiles.first?.id
            }
            if settings.defaultEmbeddingProfileID == profile.id {
                settings.defaultEmbeddingProfileID = providerProfiles.first(where: \.supportsEmbeddings)?.id
            }
            try persistSettings()
            statusMessage = "Provider profile deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateProviderSecret(_ secret: String, for profile: ProviderProfile) {
        do {
            try keychain.saveString(secret, service: keychainService, account: profile.apiKeyRef)
            providerSecrets[profile.id] = secret
            statusMessage = "Provider secret saved to Keychain."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func testProviderConnection(_ profile: ProviderProfile) {
        providerProbeRunning.insert(profile.id)
        providerProbeMessages[profile.id] = "Testing..."
        let secret = providerSecrets[profile.id] ?? ""

        Task {
            let result = await providerProbe.probe(profile: profile, apiKey: secret)
            await MainActor.run {
                self.providerProbeRunning.remove(profile.id)
                self.providerProbeMessages[profile.id] = result.message
                self.statusMessage = result.success ? "Provider \(profile.displayName) is reachable." : "Provider \(profile.displayName) probe failed."
            }
        }
    }

    public func providerReadiness(for profile: ProviderProfile) -> String {
        if !(providerSecrets[profile.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if profile.defaultModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Missing model"
            }
            return profile.supportsEmbeddings ? "Ready + embeddings" : "Ready"
        }
        return "Missing key"
    }

    public func addCategoryRule(canonical: String, aliases: String) {
        let normalized = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let rule = CategoryRule(canonical: normalized, aliases: aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        do {
            try database.saveCategoryRule(rule)
            categoryRules = try database.fetchCategoryRules()
            statusMessage = "Category rule saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteCategoryRule(_ rule: CategoryRule) {
        do {
            try database.deleteCategoryRule(id: rule.id)
            categoryRules = try database.fetchCategoryRules()
            statusMessage = "Category rule deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateDefaultReasoningProfile(_ id: String) {
        settings.defaultReasoningProfileID = id
        saveSettingsOnly()
    }

    public func updateDefaultEmbeddingProfile(_ id: String?) {
        settings.defaultEmbeddingProfileID = id
        saveSettingsOnly()
    }

    public func updateShortcuts(_ shortcuts: ShortcutSettings) {
        if let conflict = shortcuts.conflictMessage() {
            shortcutConflict = conflict
            statusMessage = conflict
            return
        }

        shortcutConflict = nil
        settings.shortcuts = shortcuts
        saveSettingsOnly()
        rebindHotKeys()
        statusMessage = "Global shortcuts updated."
    }

    public func updateCaptureSettings(_ capture: CaptureSettings) {
        settings.capture = capture
        saveSettingsOnly()
    }

    public func updateOpenAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            refreshLaunchAtLoginFlag()
            saveSettingsOnly()
            statusMessage = enabled ? "Launch at login enabled." : "Launch at login disabled."
        } catch {
            statusMessage = "Launch at login change failed: \(error.localizedDescription)"
        }
    }

    public func importLegacyExport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let count = try database.importLegacyExport(from: data)
                categoryRules = try database.fetchCategoryRules()
                try reloadClips()
                try reloadStats()
                statusMessage = "Imported \(count) legacy clips."
            } catch {
                statusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    public func exportCurrentLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "cosmogony-export-\(Date.now.formatted(.iso8601.year().month().day()))" + ".json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try database.exportLibrary()
                try data.write(to: url)
                statusMessage = "Library exported."
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func configureBridge() {
        bridge.onHandshake = { [weak self] in
            guard let self else { return UUID().uuidString }
            if let existing = self.settings.bridgeToken, !existing.isEmpty {
                return existing
            }
            let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            self.settings.bridgeToken = token
            self.saveSettingsOnly()
            return token
        }
        bridge.currentToken = { [weak self] in
            self?.settings.bridgeToken
        }
        bridge.onPageCapture = { [weak self] payload in
            self?.ingestPagePayload(payload)
        }
        bridge.onClipboardCapture = { [weak self] payload in
            self?.ingestClipboard(payload)
        }
    }

    private func rebindHotKeys() {
        hotKeys.register(
            settings: settings.shortcuts,
            onCapturePage: { [weak self] in
                Task { @MainActor in
                    self?.captureCurrentPage()
                }
            },
            onCaptureClipboard: { [weak self] in
                Task { @MainActor in
                    self?.captureClipboard()
                }
            }
        )
    }

    private func persistSettings() throws {
        try database.saveSettings(settings)
    }

    private func saveSettingsOnly() {
        do {
            try persistSettings()
            if let profiles = try? database.fetchProviderProfiles() {
                providerProfiles = profiles
            }
            if let stats = try? database.fetchStats(timebox: timeboxDraft.filter) {
                self.stats = stats
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshLaunchAtLoginFlag() {
        settings.storage.openAtLogin = launchAtLogin.isEnabled
    }

    private func categorySuggestion(for bucket: PlatformBucket, domain: String) -> String {
        if let matched = categoryRules.first(where: { rule in
            let normalized = (domain + " " + bucket.title).lowercased()
            return rule.aliases.contains(where: { normalized.contains($0.lowercased()) })
        }) {
            return matched.canonical
        }
        return bucket.title
    }

    public func openSelectedClipURL() {
        guard let urlString = selectedClip?.url, let url = URL(string: urlString), url.scheme != "clipboard" else { return }
        NSWorkspace.shared.open(url)
    }

    public func copySelectedClipURL() {
        guard let urlString = selectedClip?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        statusMessage = "URL copied."
    }
}
