import AppKit
import Foundation

public struct DuplicateCapturePrompt: Identifiable {
    public let id = UUID()
    public let clip: ClipItem
    public let successMessage: String
    public let shouldEnrich: Bool
    public let enrichmentURL: String?
    public let existingClipTitle: String

    public init(
        clip: ClipItem,
        successMessage: String,
        shouldEnrich: Bool,
        enrichmentURL: String?,
        existingClipTitle: String
    ) {
        self.clip = clip
        self.successMessage = successMessage
        self.shouldEnrich = shouldEnrich
        self.enrichmentURL = enrichmentURL
        self.existingClipTitle = existingClipTitle
    }
}

@MainActor
public final class AppModel: ObservableObject {
    @Published public var settings: AppSettings
    @Published public var providerProfiles: [ProviderProfile]
    @Published public var providerSecrets: [String: String]
    @Published public var categoryRules: [CategoryRule]
    @Published public var spaces: [Space]
    @Published public var clips: [ClipItem] = []
    @Published public var selectedScope: ClipScope = .all
    @Published public var selectedPlatform: PlatformFilter = .all
    @Published public var selectedSpaceID: String?
    @Published public var timeboxDraft = TimeboxDraft.today()
    @Published public var searchText = ""
    @Published public var captureTagDraft = ""
    @Published public var selectedClipID: String?
    @Published public var statusMessage = "Ready."
    @Published public var bridgeStatus = "Bridge offline"
    @Published public var shortcutConflict: String?
    @Published public var stats = ClipStats()
    @Published public var providerProbeMessages: [String: String] = [:]
    @Published public var providerProbeRunning = Set<String>()
    @Published public var selectedSettingsTab: SettingsTab = .appearance
    @Published public var activeOverlay: AppOverlay?
    @Published public var summaryGenerationRunning = Set<String>()
    @Published public var duplicateCapturePrompt: DuplicateCapturePrompt?
    @Published public var clipEditorHasUnsavedChanges = false
    @Published public var showUnsavedClipClosePrompt = false

    let database: AppDatabase
    private let keychain = KeychainStore()
    private let browserProbe = ChromiumBrowserProbe()
    private let pasteboardCapture = PasteboardCaptureService()
    private let enricher = ContentEnricher()
    private let bridge = LocalBridgeServer()
    private let hotKeys = HotKeyCenter()
    private let launchAtLogin = LaunchAtLoginController()
    private let providerProbe = ProviderProbeService()
    private let aiSummaryService = AISummaryService()
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
        spaces = try database.fetchSpaces()
        providerSecrets = [:]

        for profile in providerProfiles {
            providerSecrets[profile.id] = keychain.loadString(service: keychainService, account: profile.apiKeyRef)
        }

        refreshLaunchAtLoginFlag()
        configureBridge()
        rebindHotKeys()
        try bridge.start()
        bridgeStatus = "Bridge listening on 127.0.0.1:\(bridge.port)"
        try database.cleanupExpiredTrash()
        try reloadClips()
        try reloadStats()
    }

    public var selectedClip: ClipItem? {
        guard let selectedClipID else { return nil }
        if let inMemory = clips.first(where: { $0.id == selectedClipID }) {
            return inMemory
        }
        return try? database.fetchClip(id: selectedClipID)
    }

    public var searchMode: SearchMode {
        SearchScorer.mode(settings: settings, profiles: providerProfiles)
    }

    public func reloadClips() throws {
        try database.cleanupExpiredTrash()
        clips = try database.fetchClips(
            scope: selectedScope,
            platformFilter: selectedPlatform,
            spaceID: selectedSpaceID,
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

    public func resetPrimaryFilters() {
        selectedScope = .all
        selectedPlatform = .all
        selectedSpaceID = nil
        searchText = ""
        timeboxDraft = .today()
        refreshFilters()
    }

    public func focusPlatform(_ filter: PlatformFilter) {
        selectedPlatform = filter
    }

    public func focusSpace(_ id: String?) {
        selectedSpaceID = id
    }

    public func presentClipDetail(_ clip: ClipItem) {
        selectedClipID = clip.id
        clipEditorHasUnsavedChanges = false
        activeOverlay = .clipDetail
        refreshAISummary(for: clip.id)
    }

    public func closeOverlay() {
        activeOverlay = nil
        clipEditorHasUnsavedChanges = false
        showUnsavedClipClosePrompt = false
    }

    public func requestCloseOverlay() {
        if activeOverlay == .clipDetail, clipEditorHasUnsavedChanges {
            showUnsavedClipClosePrompt = true
            return
        }
        closeOverlay()
    }

    public func discardUnsavedClipChangesAndClose() {
        clipEditorHasUnsavedChanges = false
        showUnsavedClipClosePrompt = false
        closeOverlay()
    }

    public func clearSearch() {
        searchText = ""
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
        let tag = normalizedCaptureTag
        let assignedSpace = resolveSpace(for: tag)
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
            tags: tag.isEmpty ? [] : [tag],
            spaceID: assignedSpace?.id,
            spaceName: assignedSpace?.name ?? "",
            note: "",
            status: .inbox
        )
        clip.refreshSearchText()
        queueOrPersistCapture(clip, successMessage: "Captured clipboard content.")
    }

    private func ingestCurrentPage(url: String, title: String, browserName: String, excerpt: String, content: String) {
        let now = Date()
        let domain = normalizedDomain(from: url)
        let bucket = PlatformClassifier.bucket(for: url)
        let seedContent = String(content.prefix(settings.capture.maxStoredCharacters))
        let seedExcerpt = excerpt.isEmpty ? compactSummary(from: seedContent) : excerpt
        let tag = normalizedCaptureTag
        let assignedSpace = resolveSpace(for: tag)

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
            tags: tag.isEmpty ? [] : [tag],
            spaceID: assignedSpace?.id,
            spaceName: assignedSpace?.name ?? "",
            note: "",
            status: .inbox
        )
        clip.refreshSearchText()
        let shouldEnrich = settings.capture.enrichPublicPages && content.isEmpty
        queueOrPersistCapture(
            clip,
            successMessage: "Captured \(title).",
            shouldEnrich: shouldEnrich,
            enrichmentURL: shouldEnrich ? url : nil
        )
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

    private func queueOrPersistCapture(
        _ clip: ClipItem,
        successMessage: String,
        shouldEnrich: Bool = false,
        enrichmentURL: String? = nil
    ) {
        if shouldPromptForDuplicate(url: clip.url),
           let existing = try? database.fetchClip(url: clip.url) {
            duplicateCapturePrompt = DuplicateCapturePrompt(
                clip: clip,
                successMessage: successMessage,
                shouldEnrich: shouldEnrich,
                enrichmentURL: enrichmentURL,
                existingClipTitle: existing.title.isEmpty ? existing.url : existing.title
            )
            statusMessage = "Duplicate link detected."
            return
        }

        persistCapturedClip(clip, successMessage: successMessage, shouldEnrich: shouldEnrich, enrichmentURL: enrichmentURL)
    }

    private func persistCapturedClip(
        _ clip: ClipItem,
        successMessage: String,
        shouldEnrich: Bool,
        enrichmentURL: String?
    ) {
        persist(clip)
        statusMessage = successMessage

        guard shouldEnrich, let enrichmentURL else { return }
        Task {
            let enrichment = await enricher.enrich(from: enrichmentURL, maxLength: settings.capture.maxStoredCharacters)
            await MainActor.run {
                self.applyEnrichment(for: clip.id, excerpt: enrichment.excerpt, content: enrichment.content)
            }
        }
    }

    private func shouldPromptForDuplicate(url: String) -> Bool {
        guard let parsedURL = URL(string: url), let scheme = parsedURL.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    public func confirmDuplicateCapture() {
        guard let prompt = duplicateCapturePrompt else { return }
        duplicateCapturePrompt = nil
        persistCapturedClip(
            prompt.clip,
            successMessage: prompt.successMessage,
            shouldEnrich: prompt.shouldEnrich,
            enrichmentURL: prompt.enrichmentURL
        )
    }

    public func cancelDuplicateCapture() {
        duplicateCapturePrompt = nil
        statusMessage = "Capture cancelled."
    }

    public func saveClipEdits(
        id: String,
        aiSummary: String,
        category: String,
        tagsText: String,
        note: String,
        status: ClipStatus
    ) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            let previousStatus = clip.status
            clip.aiSummary = aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            clip.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
            clip.tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let assignedSpace = resolveSpace(forTags: clip.tags)
            clip.spaceID = assignedSpace?.id
            clip.spaceName = assignedSpace?.name ?? ""
            clip.note = note
            clip.status = status
            if status == .trashed {
                clip.trashedAt = previousStatus == .trashed ? clip.trashedAt ?? .now : .now
            } else {
                clip.trashedAt = nil
            }
            clip.refreshSearchText()
            try database.saveClip(clip)
            try reloadClips()
            try reloadStats()
            selectedClipID = clip.id
            clipEditorHasUnsavedChanges = false
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

    public func testProviderConnection(_ profile: ProviderProfile, apiKeyOverride: String? = nil) {
        providerProbeRunning.insert(profile.id)
        providerProbeMessages[profile.id] = "Testing..."
        let secret = (apiKeyOverride ?? providerSecrets[profile.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

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

    public func addSpace(name: String, tagsText: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let space = Space(name: normalizedName, tags: tags)
        do {
            try database.saveSpace(space)
            spaces = try database.fetchSpaces()
            statusMessage = "Space created."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteSpace(_ space: Space) {
        do {
            try database.deleteSpace(id: space.id)
            spaces = try database.fetchSpaces()
            if selectedSpaceID == space.id {
                selectedSpaceID = nil
            }
            try reloadClips()
            try reloadStats()
            statusMessage = "Space deleted."
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

    public func updateAppearance(_ appearance: AppAppearance) {
        settings.appearance = appearance
        saveSettingsOnly()
        statusMessage = "Appearance updated."
    }

    public func openSettingsTab(_ tab: SettingsTab) {
        selectedSettingsTab = tab
        activeOverlay = .settings
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
            if let spaces = try? database.fetchSpaces() {
                self.spaces = spaces
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

    public func updateSelectedClipStatus(_ status: ClipStatus) {
        guard let clip = selectedClip else { return }
        saveClipEdits(
            id: clip.id,
            aiSummary: clip.aiSummary,
            category: clip.category,
            tagsText: clip.tags.joined(separator: ", "),
            note: clip.note,
            status: status
        )
    }

    public func syncClipEditorDirtyState(
        clipID: String,
        aiSummary: String,
        category: String,
        tagsText: String,
        note: String,
        status: ClipStatus
    ) {
        guard let clip = try? database.fetchClip(id: clipID) else {
            clipEditorHasUnsavedChanges = false
            return
        }

        let normalizedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        clipEditorHasUnsavedChanges =
            clip.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines) != aiSummary.trimmingCharacters(in: .whitespacesAndNewlines) ||
            clip.category.trimmingCharacters(in: .whitespacesAndNewlines) != category.trimmingCharacters(in: .whitespacesAndNewlines) ||
            clip.tags != normalizedTags ||
            clip.note != note ||
            clip.status != status
    }

    public func togglePin(for clip: ClipItem) {
        do {
            guard var stored = try database.fetchClip(id: clip.id) else { return }
            stored.isPinned.toggle()
            try database.saveClip(stored)
            try reloadClips()
            try reloadStats()
            selectedClipID = stored.id
            statusMessage = stored.isPinned ? "Clip pinned." : "Clip unpinned."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteOrTrash(_ clip: ClipItem) {
        do {
            guard var stored = try database.fetchClip(id: clip.id) else { return }
            if stored.status == .trashed {
                try database.deleteClip(id: stored.id)
                try reloadClips()
                try reloadStats()
                statusMessage = "Clip deleted permanently."
                return
            }

            stored.status = .trashed
            stored.trashedAt = .now
            try database.saveClip(stored)
            try reloadClips()
            try reloadStats()
            statusMessage = "Clip moved to trash."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func refreshAISummary(for id: String) {
        guard !summaryGenerationRunning.contains(id) else { return }
        guard let clip = try? database.fetchClip(id: id) else { return }
        guard let profile = preferredSummaryProfile(), let apiKey = providerSecrets[profile.id], !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        summaryGenerationRunning.insert(id)
        Task {
            do {
                let result = try await aiSummaryService.summarizeChinese(clip: clip, profile: profile, apiKey: apiKey)
                await MainActor.run {
                    self.summaryGenerationRunning.remove(id)
                    self.persistAISummary(id: id, summary: result.summary)
                    self.statusMessage = "AI summary refreshed."
                }
            } catch {
                await MainActor.run {
                    self.summaryGenerationRunning.remove(id)
                    self.statusMessage = "AI summary failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var normalizedCaptureTag: String {
        captureTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func resolveSpace(for tag: String) -> Space? {
        guard !tag.isEmpty else { return nil }
        return spaces.first { space in
            space.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
        }
    }

    private func resolveSpace(forTags tags: [String]) -> Space? {
        for tag in tags {
            if let matched = resolveSpace(for: tag.lowercased()) {
                return matched
            }
        }
        return nil
    }

    private func preferredSummaryProfile() -> ProviderProfile? {
        if let deepSeek = providerProfiles.first(where: { $0.kind == .deepseek && $0.enabled && !(providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return deepSeek
        }
        if let defaultID = settings.defaultReasoningProfileID,
           let profile = providerProfiles.first(where: { $0.id == defaultID && $0.enabled && !(providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return profile
        }
        return providerProfiles.first(where: { $0.enabled && !(providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    private func persistAISummary(id: String, summary: String) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            clip.aiSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            clip.refreshSearchText()
            try database.saveClip(clip)
            try reloadClips()
        } catch {
            statusMessage = "Saving AI summary failed: \(error.localizedDescription)"
        }
    }
}
