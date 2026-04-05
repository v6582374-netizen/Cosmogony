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
    @Published public var searchDraft = ""
    @Published public private(set) var activeSearchQuery = ""
    @Published public private(set) var aiSearchStatus: AISearchStatus = .idle
    @Published public private(set) var aiSearchResults: [AISearchResult] = []
    @Published public private(set) var aiSearchTrace: SearchTraceV2?
    @Published public var isRecallOverlayPresented = false
    @Published public var overlayMode: OverlayMode = .recall
    @Published public var backstageModule: BackstageModule = .clips
    @Published public var isBackstageSidebarCollapsed = false
    @Published public var backstageExpandedSectionIDs: Set<String> = [
        "clips.platform",
        "clips.scope",
        "clips.space",
        "clips.timebox",
        "prompt.actions",
        "prompt.library",
        "prompt.source",
        "todo.quick",
        "todo.queue",
        "settings.tabs"
    ]
    @Published public var recallHighlightedResultID: String?
    @Published public var todoItems: [TodoItem] = []
    @Published public var todoDraft = ""
    @Published public var todoFocusedItemID: String?
    @Published public var todoEditingItemID: String?
    @Published public var todoEditingDraft = ""
    @Published public var promptItems: [PromptLibraryItem] = []
    @Published public var selectedPromptID: String?
    @Published public var promptRenamingItemID: String?
    @Published public var promptRenamingDraft = ""
    @Published public var overlayToast: OverlayToast?
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
    @Published public var readingGenerationRunning = Set<String>()
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
    private let aiQueryIntentService = AIQueryIntentService()
    private let embeddingService = EmbeddingService()
    private let aiRerankService = AIRerankService()
    private let keychainService = "Cosmogony.ProviderSecrets"
    private var searchAliasRules: [SearchAliasRule]
    private var searchDebounceTask: Task<Void, Never>?
    private var aiSearchTask: Task<Void, Never>?
    private var semanticIndexTask: Task<Void, Error>?
    private var semanticIndexTaskKey: String?
    private var aiSearchGeneration = 0
    private var overlayToastTask: Task<Void, Never>?
    private var queryRewriteCache: [String: QueryRewrite] = [:]
    private var queryEmbeddingCache: [String: [Double]] = [:]
    private var localCandidateCache: [String: [SearchCandidate]] = [:]
    private var pendingClipSelectionID: String?

    public var activateBackstageHandler: (() -> Void)?

    private enum SearchExecutionTrigger {
        case typing
        case submitted
    }

    public static func bootstrap() -> AppModel {
        do {
            return try AppModel()
        } catch {
            fatalError("Cosmogony bootstrap failed: \(error)")
        }
    }

    public convenience init() throws {
        try self.init(database: AppDatabase(), startRuntimeServices: true, loadKeychainSecrets: true)
    }

    package static func makeChecksModel() throws -> AppModel {
        try AppModel(database: AppDatabase(inMemory: true), startRuntimeServices: false, loadKeychainSecrets: false)
    }

    private init(database: AppDatabase, startRuntimeServices: Bool, loadKeychainSecrets: Bool) throws {
        settings = try database.fetchSettings()
        providerProfiles = try database.fetchProviderProfiles()
        categoryRules = try database.fetchCategoryRules()
        spaces = try database.fetchSpaces()
        searchAliasRules = try database.fetchSearchAliasRules()
        providerSecrets = [:]
        self.database = database

        if loadKeychainSecrets {
            for profile in providerProfiles {
                providerSecrets[profile.id] = keychain.loadString(service: keychainService, account: profile.apiKeyRef)
            }
        }

        try migrateLegacyShortcutDefaultsIfNeeded()

        refreshLaunchAtLoginFlag()
        if startRuntimeServices {
            configureBridge()
            rebindHotKeys()
            try bridge.start()
            bridgeStatus = "Bridge listening on 127.0.0.1:\(bridge.port)"
        } else {
            bridgeStatus = "Bridge disabled for checks"
        }
        try database.cleanupExpiredTrash()
        try reloadClips()
        try reloadStats()
        try reloadTodoItems()
        try reloadPromptItems()
        scheduleSemanticIndexBackfillIfNeeded()
    }

    public var selectedClip: ClipItem? {
        guard let selectedClipID else { return nil }
        if let inMemory = clips.first(where: { $0.id == selectedClipID }) {
            return inMemory
        }
        return try? database.fetchClip(id: selectedClipID)
    }

    public var searchMode: SearchMode {
        SearchScorer.mode(settings: settings, profiles: providerProfiles, providerSecrets: providerSecrets)
    }

    public var isAISearchActive: Bool {
        !activeSearchQuery.isEmpty || aiSearchStatus.isBusy
    }

    public var isAISearchContextActive: Bool {
        !SemanticSearchToolkit.normalizedQuery(searchDraft).isEmpty || isAISearchActive
    }

    public var filteredAISearchResults: [AISearchResult] {
        aiSearchResults.filter { clipMatchesCurrentFilters($0.clip) }
    }

    public var displayedClips: [ClipItem] {
        isAISearchActive ? filteredAISearchResults.map(\.clip) : clips
    }

    public var recallResults: [AISearchResult] {
        Array(filteredAISearchResults.prefix(6))
    }

    public var recallHighlightedResult: AISearchResult? {
        let results = recallResults
        guard !results.isEmpty else { return nil }
        if let recallHighlightedResultID,
           let highlighted = results.first(where: { $0.id == recallHighlightedResultID }) {
            return highlighted
        }
        return results.first
    }

    public var todoEditingItem: TodoItem? {
        guard let todoEditingItemID else { return nil }
        return todoItems.first(where: { $0.id == todoEditingItemID })
    }

    public var selectedPrompt: PromptLibraryItem? {
        guard let selectedPromptID else { return promptItems.first }
        return promptItems.first(where: { $0.id == selectedPromptID }) ?? promptItems.first
    }

    public var promptRenamingItem: PromptLibraryItem? {
        guard let promptRenamingItemID else { return nil }
        return promptItems.first(where: { $0.id == promptRenamingItemID })
    }

    public func reloadClips() throws {
        try database.cleanupExpiredTrash()
        clips = try database.fetchClips(
            scope: selectedScope,
            platformFilter: selectedPlatform,
            spaceID: selectedSpaceID,
            timebox: timeboxDraft.filter,
            search: "",
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

    public func reloadTodoItems() throws {
        todoItems = try database.fetchPendingTodoItems()
        if let todoFocusedItemID, !todoItems.contains(where: { $0.id == todoFocusedItemID }) {
            self.todoFocusedItemID = nil
        }
        if let todoEditingItemID, !todoItems.contains(where: { $0.id == todoEditingItemID }) {
            self.todoEditingItemID = nil
            todoEditingDraft = ""
        }
    }

    public func reloadPromptItems() throws {
        promptItems = try database.fetchPromptLibraryItems()
        if let selectedPromptID, !promptItems.contains(where: { $0.id == selectedPromptID }) {
            self.selectedPromptID = promptItems.first?.id
        } else if self.selectedPromptID == nil {
            self.selectedPromptID = promptItems.first?.id
        }
        if let promptRenamingItemID, !promptItems.contains(where: { $0.id == promptRenamingItemID }) {
            self.promptRenamingItemID = nil
            promptRenamingDraft = ""
        }
    }

    public func refreshFilters() {
        do {
            try reloadClips()
            try reloadStats()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func resetPrimaryFilters(clearSearch: Bool = false) {
        selectedScope = .all
        selectedPlatform = .all
        selectedSpaceID = nil
        if clearSearch {
            resetAISearchState()
        }
        timeboxDraft = .today()
        refreshFilters()
    }

    public func focusPlatform(_ filter: PlatformFilter) {
        selectedPlatform = filter
    }

    public func focusSpace(_ id: String?) {
        selectedSpaceID = id
    }

    public func openBackstageModule(_ module: BackstageModule) {
        backstageModule = module
        activeOverlay = nil
        switch module {
        case .clips:
            if selectedClipID == nil {
                selectedClipID = displayedClips.first?.id
            }
        case .todo:
            if todoFocusedItemID == nil {
                todoFocusedItemID = todoItems.first?.id
            }
        case .promptLibrary:
            if selectedPromptID == nil {
                selectedPromptID = promptItems.first?.id
            }
        case .settings:
            break
        }
    }

    public func toggleBackstageSidebar() {
        isBackstageSidebarCollapsed.toggle()
    }

    public func setBackstageSidebarCollapsed(_ collapsed: Bool) {
        isBackstageSidebarCollapsed = collapsed
    }

    public func isBackstageSectionExpanded(module: BackstageModule, sectionID: String) -> Bool {
        backstageExpandedSectionIDs.contains(backstageSectionKey(module: module, sectionID: sectionID))
    }

    public func toggleBackstageSection(module: BackstageModule, sectionID: String) {
        let key = backstageSectionKey(module: module, sectionID: sectionID)
        if backstageExpandedSectionIDs.contains(key) {
            backstageExpandedSectionIDs.remove(key)
        } else {
            backstageExpandedSectionIDs.insert(key)
        }
    }

    public func setBackstageSectionExpanded(_ expanded: Bool, module: BackstageModule, sectionID: String) {
        let key = backstageSectionKey(module: module, sectionID: sectionID)
        if expanded {
            backstageExpandedSectionIDs.insert(key)
        } else {
            backstageExpandedSectionIDs.remove(key)
        }
    }

    public func presentClipDetail(_ clip: ClipItem) {
        selectedClipID = clip.id
        clipEditorHasUnsavedChanges = false
        pendingClipSelectionID = nil
        activeOverlay = .clipDetail
        recordSearchSelection(for: clip)
        queueAutomaticAIEnrichmentIfNeeded(for: clip.id)
    }

    public func focusClipInBackstage(_ clip: ClipItem) {
        if clipEditorHasUnsavedChanges, selectedClipID != clip.id {
            pendingClipSelectionID = clip.id
            showUnsavedClipClosePrompt = true
            return
        }

        pendingClipSelectionID = nil
        selectedClipID = clip.id
        clipEditorHasUnsavedChanges = false
        activeOverlay = nil
        recordSearchSelection(for: clip)
        queueAutomaticAIEnrichmentIfNeeded(for: clip.id)
    }

    public func closeOverlay() {
        activeOverlay = nil
        clipEditorHasUnsavedChanges = false
        showUnsavedClipClosePrompt = false
        pendingClipSelectionID = nil
    }

    public func requestCloseOverlay() {
        if activeOverlay == .clipDetail, clipEditorHasUnsavedChanges {
            showUnsavedClipClosePrompt = true
            return
        }
        closeOverlay()
    }

    public func discardUnsavedClipChangesAndClose() {
        let pendingSelection = pendingClipSelectionID
        clipEditorHasUnsavedChanges = false
        showUnsavedClipClosePrompt = false
        pendingClipSelectionID = nil
        activeOverlay = nil

        if let pendingSelection,
           let clip = try? database.fetchClip(id: pendingSelection) {
            selectedClipID = clip.id
            recordSearchSelection(for: clip)
            queueAutomaticAIEnrichmentIfNeeded(for: clip.id)
            return
        }

        closeOverlay()
    }

    public func cancelPendingClipSelection() {
        pendingClipSelectionID = nil
        showUnsavedClipClosePrompt = false
    }

    public func clearSearch() {
        searchDraft = ""
        resetAISearchState()
    }

    public func presentRecallOverlay(resetSession: Bool = true, initialMode: OverlayMode = .recall) {
        if resetSession {
            searchDraft = ""
            resetAISearchState()
            recallHighlightedResultID = nil
        }
        finishTodoEditing(commit: true)
        finishPromptRenaming(commit: true)
        overlayMode = initialMode
        isRecallOverlayPresented = true
    }

    public func dismissRecallOverlay(clearSession: Bool = true) {
        finishTodoEditing(commit: true)
        finishPromptRenaming(commit: true)
        isRecallOverlayPresented = false
        recallHighlightedResultID = nil
        todoFocusedItemID = nil
        overlayToastTask?.cancel()
        overlayToast = nil
        if clearSession {
            searchDraft = ""
            resetAISearchState()
        }
    }

    public func toggleRecallOverlay() {
        if isRecallOverlayPresented {
            dismissRecallOverlay()
            return
        }
        presentRecallOverlay(initialMode: .recall)
    }

    public func setOverlayMode(_ mode: OverlayMode) {
        guard overlayMode != mode else { return }
        finishTodoEditing(commit: true)
        finishPromptRenaming(commit: true)
        overlayMode = mode
        if mode == .recall {
            todoFocusedItemID = nil
        }
    }

    public func cycleOverlayMode() {
        switch overlayMode {
        case .recall:
            setOverlayMode(.todo)
        case .todo:
            setOverlayMode(.promptLibrary)
        case .promptLibrary:
            setOverlayMode(.recall)
        }
    }

    public func setRecallHighlightedResult(_ id: String?) {
        recallHighlightedResultID = id
        if let id {
            selectedClipID = id
        }
    }

    public func moveRecallSelection(offset: Int) {
        let results = recallResults
        guard !results.isEmpty else { return }

        let currentID = recallHighlightedResult?.id ?? results.first?.id
        let currentIndex = currentID.flatMap { id in results.firstIndex(where: { $0.id == id }) } ?? 0
        let nextIndex = max(0, min(results.count - 1, currentIndex + offset))
        let nextID = results[nextIndex].id
        recallHighlightedResultID = nextID
        selectedClipID = nextID
    }

    public func confirmRecallSelection() {
        guard let result = recallHighlightedResult ?? recallResults.first else { return }
        recallHighlightedResultID = result.id
        selectedClipID = result.id
    }

    public func enterBackstageFromRecall() {
        backstageModule = .clips
        if let result = recallHighlightedResult ?? recallResults.first {
            recordSearchSelection(for: result.clip)
        }
        confirmRecallSelection()
        isRecallOverlayPresented = false
        activateBackstageHandler?()
    }

    public func enterBackstageFromOverlay() {
        switch overlayMode {
        case .recall:
            enterBackstageFromRecall()
        case .todo:
            finishTodoEditing(commit: true)
            backstageModule = .todo
            dismissRecallOverlay(clearSession: false)
            activateBackstageHandler?()
        case .promptLibrary:
            finishPromptRenaming(commit: true)
            backstageModule = .promptLibrary
            dismissRecallOverlay(clearSession: false)
            activateBackstageHandler?()
        }
    }

    public func openRecallHighlightedResultURL() {
        if let result = recallHighlightedResult ?? recallResults.first {
            recordSearchSelection(for: result.clip)
        }
        confirmRecallSelection()
        openSelectedClipURL()
        dismissRecallOverlay()
    }

    public func selectTodoItem(_ id: String?) {
        todoFocusedItemID = id
    }

    public func selectPromptItem(_ id: String?) {
        selectedPromptID = id
    }

    public func submitTodoDraft() {
        let normalized = todoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        do {
            let now = Date()
            let item = TodoItem(
                title: normalized,
                createdAt: now,
                updatedAt: now,
                visualSeed: Int.random(in: 0...999_999)
            )
            try database.saveTodoItem(item)
            try reloadTodoItems()
            todoDraft = ""
            todoFocusedItemID = item.id
            statusMessage = "Todo added."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func beginTodoEditing(_ item: TodoItem) {
        if todoEditingItemID != nil, todoEditingItemID != item.id {
            finishTodoEditing(commit: true)
        }
        todoFocusedItemID = item.id
        todoEditingItemID = item.id
        todoEditingDraft = item.title
    }

    public func finishTodoEditing(commit: Bool) {
        guard let itemID = todoEditingItemID else { return }
        defer {
            todoEditingItemID = nil
            todoEditingDraft = ""
        }

        guard commit else { return }
        let normalized = todoEditingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        do {
            guard var item = try database.fetchTodoItem(id: itemID) else { return }
            guard item.title != normalized else { return }
            item.title = normalized
            item.updatedAt = .now
            try database.saveTodoItem(item)
            try reloadTodoItems()
            todoFocusedItemID = item.id
            statusMessage = "Todo updated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func completeTodo(_ itemID: String) {
        do {
            guard var item = try database.fetchTodoItem(id: itemID) else { return }
            guard item.completedAt == nil else { return }
            item.completedAt = .now
            item.updatedAt = item.completedAt ?? .now
            try database.saveTodoItem(item)
            if todoEditingItemID == itemID {
                todoEditingItemID = nil
                todoEditingDraft = ""
            }
            if todoFocusedItemID == itemID {
                todoFocusedItemID = nil
            }
            try reloadTodoItems()
            statusMessage = "Todo completed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func createPromptLibraryItem() {
        do {
            let now = Date()
            let item = PromptLibraryItem(
                title: "新提示词",
                content: "",
                sourceLabel: "Custom",
                sourceURL: "",
                createdAt: now,
                updatedAt: now,
                isSystem: false
            )
            try database.savePromptLibraryItem(item)
            try reloadPromptItems()
            backstageModule = .promptLibrary
            selectedPromptID = item.id
            statusMessage = "Prompt created."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func beginPromptRenaming(_ item: PromptLibraryItem) {
        if promptRenamingItemID != nil, promptRenamingItemID != item.id {
            finishPromptRenaming(commit: true)
        }
        selectedPromptID = item.id
        promptRenamingItemID = item.id
        promptRenamingDraft = item.title
    }

    public func finishPromptRenaming(commit: Bool) {
        guard let itemID = promptRenamingItemID else { return }
        defer {
            promptRenamingItemID = nil
            promptRenamingDraft = ""
        }

        guard commit else { return }
        let normalized = promptRenamingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        do {
            guard var item = try database.fetchPromptLibraryItem(id: itemID) else { return }
            guard item.title != normalized else { return }
            item.title = normalized
            item.updatedAt = .now
            try database.savePromptLibraryItem(item)
            try reloadPromptItems()
            selectedPromptID = item.id
            statusMessage = "Prompt title updated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func savePromptLibraryItemEdits(id: String, title: String, content: String) {
        do {
            guard var item = try database.fetchPromptLibraryItem(id: id) else { return }
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.title : title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            item.updatedAt = .now
            try database.savePromptLibraryItem(item)
            try reloadPromptItems()
            selectedPromptID = item.id
            statusMessage = "Prompt saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func copyPromptLibraryContent(_ item: PromptLibraryItem) {
        let text = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        selectedPromptID = item.id
        if isRecallOverlayPresented {
            showOverlayToast(message: "已复制提示词")
        } else {
            statusMessage = "Prompt copied."
        }
    }

    public func enterBackstageForPromptLibrary(_ itemID: String) {
        finishPromptRenaming(commit: true)
        selectedPromptID = itemID
        backstageModule = .promptLibrary
        dismissRecallOverlay(clearSession: false)
        activateBackstageHandler?()
    }

    package func injectRecallResultsForChecks(query: String, results: [AISearchResult]) {
        searchDraft = query
        activeSearchQuery = query
        aiSearchResults = results
        aiSearchStatus = .complete("Checks")
        recallHighlightedResultID = results.first?.id
        if let first = results.first {
            selectedClipID = first.id
        }
    }

    package func checkClipForRecallFlow(matching text: String) -> ClipItem? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allClips = (try? database.fetchNonTrashClips()) ?? []
        if normalized.isEmpty {
            return allClips.first
        }
        return allClips.first(where: { clip in
            let haystack = [
                clip.title,
                clip.domain,
                clip.excerpt,
                clip.aiSummary,
                clip.url,
                clip.tags.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(normalized)
        }) ?? allClips.first
    }

    public func scheduleAISearch() {
        searchDebounceTask?.cancel()
        let query = SemanticSearchToolkit.normalizedQuery(searchDraft)
        guard !query.isEmpty else {
            resetAISearchState()
            return
        }

        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await self?.beginAISearch(query: query, trigger: .typing)
        }
    }

    public func submitAISearch(forceImmediate: Bool) async {
        searchDebounceTask?.cancel()
        let query = SemanticSearchToolkit.normalizedQuery(searchDraft)
        guard !query.isEmpty else {
            resetAISearchState()
            return
        }

        await beginAISearch(query: query, trigger: forceImmediate ? .submitted : .typing)
    }

    private func beginAISearch(query: String, trigger: SearchExecutionTrigger) async {
        aiSearchTask?.cancel()
        aiSearchGeneration += 1
        let generation = aiSearchGeneration
        activeSearchQuery = query
        aiSearchStatus = .searching(trigger == .submitted ? "Understanding your query..." : "Matching local signals...")

        aiSearchTask = Task { [weak self] in
            await self?.runAISearch(query: query, generation: generation, trigger: trigger)
        }
    }

    public func cancelAISearch() {
        resetAISearchState()
    }

    public func goHome() {
        guard !(activeOverlay == .clipDetail && clipEditorHasUnsavedChanges) else {
            showUnsavedClipClosePrompt = true
            return
        }

        backstageModule = .clips
        closeOverlay()
        searchDraft = ""
        resetAISearchState()
        resetPrimaryFilters()
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
        let clipID = UUID().uuidString
        let parsedURL = URL(string: rawText)
        let scheme = parsedURL?.scheme?.lowercased()
        let isWebURL = scheme == "http" || scheme == "https"
        let clippedURL = isWebURL ? parsedURL?.absoluteString : nil
        let title = clipboardDisplayTitle(from: rawText)
        let url = isWebURL ? clippedURL ?? "clipboard://capture/\(clipID)" : "clipboard://capture/\(clipID)"
        let tag = normalizedCaptureTag
        let assignedSpace = resolveSpace(for: tag)
        var clip = ClipItem(
            id: clipID,
            sourceType: .clipboard,
            url: url,
            title: title,
            domain: payload.sourceApplication ?? "Clipboard",
            platformBucket: isWebURL ? PlatformClassifier.bucket(for: rawText) : .otherWeb,
            capturedAt: now,
            capturedHourBucket: floorToHour(now),
            excerpt: compactSummary(from: rawText),
            content: String(rawText.prefix(settings.capture.maxStoredCharacters)),
            aiSummary: "",
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
            aiSummary: "",
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
            clip.status = .library
            clip.refreshSearchText()
            try database.saveClip(clip)
            scheduleSemanticIndexRefresh(for: clip)
            try reloadClips()
            refreshAISearchIfNeeded()
            queueAutomaticAIEnrichmentIfNeeded(for: clip.id, force: true)
        } catch {
            statusMessage = "Enrichment failed: \(error.localizedDescription)"
        }
    }

    private func persist(_ clip: ClipItem) {
        do {
            try database.saveClip(clip)
            scheduleSemanticIndexRefresh(for: clip)
            try reloadClips()
            try reloadStats()
            selectedClipID = clip.id
            refreshAISearchIfNeeded()
            queueAutomaticAIEnrichmentIfNeeded(for: clip.id)
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
        maybeGenerateClipboardReading(for: clip)

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
        status: ClipStatus,
        contentText: String? = nil
    ) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            let previousStatus = clip.status
            let requestedAISummary = aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousContent = clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
            var contentChanged = false

            if let contentText {
                let normalizedContent = String(contentText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(settings.capture.maxStoredCharacters))
                if clip.content != normalizedContent {
                    contentChanged = previousContent != normalizedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    clip.content = normalizedContent
                    clip.excerpt = compactSummary(from: normalizedContent)
                    if clip.isPlainTextClipboardCapture {
                        clip.title = clipboardDisplayTitle(from: normalizedContent)
                        clip.readingPayloadJSON = ""
                    }
                }
            }

            clip.aiSummary = requestedAISummary
            clip.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
            clip.tags = normalizedOrderedTags(from: tagsText)
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
            scheduleSemanticIndexRefresh(for: clip)
            try reloadClips()
            try reloadStats()
            selectedClipID = clip.id
            clipEditorHasUnsavedChanges = false
            pendingClipSelectionID = nil
            refreshAISearchIfNeeded()
            maybeGenerateClipboardReading(for: clip)
            if contentChanged {
                queueAutomaticAIEnrichmentIfNeeded(for: clip.id, force: true)
            }
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
            invalidateSearchCaches()
            semanticIndexTaskKey = nil
            semanticIndexTask?.cancel()
            scheduleSemanticIndexBackfillIfNeeded()
            refreshAISearchIfNeeded()
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
            invalidateSearchCaches(includingRewrite: true)
            semanticIndexTaskKey = nil
            semanticIndexTask?.cancel()
            refreshAISearchIfNeeded()
            statusMessage = "Provider profile deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateProviderSecret(_ secret: String, for profile: ProviderProfile) {
        do {
            try keychain.saveString(secret, service: keychainService, account: profile.apiKeyRef)
            providerSecrets[profile.id] = secret
            invalidateSearchCaches()
            scheduleSemanticIndexBackfillIfNeeded()
            refreshAISearchIfNeeded()
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
            refreshAISearchIfNeeded()
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
        semanticIndexTaskKey = nil
        semanticIndexTask?.cancel()
        saveSettingsOnly()
        refreshAISearchIfNeeded()
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
        statusMessage = "Recall and clipboard shortcuts updated."
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
        openBackstageModule(.settings)
        activateBackstageHandler?()
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

    public func exportAllContent() {
        exportCurrentLibrary()
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
            onOpenRecallOverlay: { [weak self] in
                Task { @MainActor in
                    self?.toggleRecallOverlay()
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

    private func backstageSectionKey(module: BackstageModule, sectionID: String) -> String {
        "\(module.rawValue).\(sectionID)"
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

    public func openClipURL(_ clip: ClipItem) {
        guard let url = URL(string: clip.url), url.scheme != "clipboard" else { return }
        NSWorkspace.shared.open(url)
    }

    public func copySelectedClipURL() {
        guard let urlString = selectedClip?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        statusMessage = "URL copied."
    }

    public func copyClipURL(_ clip: ClipItem) {
        guard !clip.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clip.url, forType: .string)
        statusMessage = "URL copied."
    }

    public func copySelectedClipContent() {
        guard let clip = selectedClip else { return }
        copyText(clip.content)
    }

    public func copyText(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Clipboard text copied."
    }

    public func copySelectedPromptContent() {
        guard let selectedPrompt else { return }
        copyPromptLibraryContent(selectedPrompt)
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
        status: ClipStatus,
        contentText: String? = nil
    ) {
        guard let clip = try? database.fetchClip(id: clipID) else {
            clipEditorHasUnsavedChanges = false
            return
        }

        let normalizedTags = normalizedOrderedTags(from: tagsText)

        clipEditorHasUnsavedChanges =
            clip.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines) != aiSummary.trimmingCharacters(in: .whitespacesAndNewlines) ||
            clip.category.trimmingCharacters(in: .whitespacesAndNewlines) != category.trimmingCharacters(in: .whitespacesAndNewlines) ||
            clip.tags != normalizedTags ||
            clip.note != note ||
            clip.status != status ||
            (contentText != nil && clip.content.trimmingCharacters(in: .whitespacesAndNewlines) != contentText?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func togglePin(for clip: ClipItem) {
        do {
            guard var stored = try database.fetchClip(id: clip.id) else { return }
            stored.isPinned.toggle()
            try database.saveClip(stored)
            try reloadClips()
            try reloadStats()
            synchronizeAISearchResults(updatedClip: stored)
            selectedClipID = stored.id
            refreshAISearchIfNeeded()
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
                synchronizeAISearchResults(removedClipIDs: [stored.id])
                refreshAISearchIfNeeded()
                statusMessage = "Clip deleted permanently."
                return
            }

            stored.status = .trashed
            stored.trashedAt = .now
            try database.saveClip(stored)
            try reloadClips()
            try reloadStats()
            synchronizeAISearchResults(removedClipIDs: [stored.id])
            refreshAISearchIfNeeded()
            statusMessage = "Clip moved to trash."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func markClipAsRead(_ clip: ClipItem) {
        do {
            guard var stored = try database.fetchClip(id: clip.id) else { return }
            guard stored.status != .trashed else { return }
            stored.status = .library
            stored.trashedAt = nil
            try database.saveClip(stored)
            try reloadClips()
            try reloadStats()
            synchronizeAISearchResults(updatedClip: stored)
            selectedClipID = stored.id
            refreshAISearchIfNeeded()
            statusMessage = stored.status == .library ? "Clip marked as read." : "Clip updated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func refreshAIEnrichment(for id: String, force: Bool = true) {
        guard !summaryGenerationRunning.contains(id) else { return }
        guard let clip = try? database.fetchClip(id: id) else { return }
        guard let profile = preferredSummaryProfile(), let apiKey = providerSecrets[profile.id], !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard force || clipNeedsAIEnrichment(clip) else { return }

        summaryGenerationRunning.insert(id)
        Task {
            do {
                let result = try await aiSummaryService.generateClipEnrichment(clip: clip, profile: profile, apiKey: apiKey)
                await MainActor.run {
                    self.summaryGenerationRunning.remove(id)
                    self.persistAIEnrichment(
                        id: id,
                        summary: result.summary,
                        category: result.category,
                        tags: result.tags
                    )
                    self.statusMessage = "AI analysis refreshed."
                }
            } catch {
                await MainActor.run {
                    self.summaryGenerationRunning.remove(id)
                    self.statusMessage = "AI analysis failed: \(error.localizedDescription)"
                }
            }
        }
    }

    public func refreshClipboardReading(for id: String, force: Bool = false) {
        guard !readingGenerationRunning.contains(id) else { return }
        guard let clip = try? database.fetchClip(id: id), clip.isPlainTextClipboardCapture else { return }
        guard force || clip.readingPayload == nil else { return }
        guard isLikelyEnglishText(clip.content) else { return }
        guard let profile = preferredSummaryProfile(), let apiKey = providerSecrets[profile.id], !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        readingGenerationRunning.insert(id)
        Task {
            do {
                let result = try await aiSummaryService.generateClipboardReading(clip: clip, profile: profile, apiKey: apiKey)
                await MainActor.run {
                    self.readingGenerationRunning.remove(id)
                    self.persistClipboardReading(id: id, payload: result.payload)
                    self.statusMessage = "Bilingual clipboard reading refreshed."
                }
            } catch {
                await MainActor.run {
                    self.readingGenerationRunning.remove(id)
                    self.statusMessage = "Bilingual reading failed: \(error.localizedDescription)"
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

    private func clipNeedsAIEnrichment(_ clip: ClipItem) -> Bool {
        let summary = clip.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty || clip.tags.count < 5
    }

    private func queueAutomaticAIEnrichmentIfNeeded(for id: String, force: Bool = false) {
        guard let clip = try? database.fetchClip(id: id) else { return }
        guard force || clipNeedsAIEnrichment(clip) else { return }
        refreshAIEnrichment(for: id, force: true)
    }

    private func normalizedOrderedTags(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;\n")
        let rawTags = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var result: [String] = []

        for rawTag in rawTags {
            let collapsedWhitespace = rawTag.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            let normalized = collapsedWhitespace.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let output = normalized == collapsedWhitespace ? collapsedWhitespace.lowercased() : collapsedWhitespace
            let key = output.lowercased()
            guard !output.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(output)
        }

        return result
    }

    private func clipMatchesCurrentFilters(_ clip: ClipItem) -> Bool {
        switch selectedPlatform {
        case .all:
            break
        case let .bucket(bucket):
            guard clip.platformBucket == bucket else { return false }
        }

        switch selectedScope {
        case .all:
            break
        case .inbox:
            guard clip.status == .inbox else { return false }
        case .library:
            guard clip.status == .library else { return false }
        case .trash:
            guard clip.status == .trashed else { return false }
        }

        if let selectedSpaceID, clip.spaceID != selectedSpaceID {
            return false
        }

        return timeboxDraft.filter.contains(clip.capturedAt)
    }

    private func maybeGenerateClipboardReading(for clip: ClipItem) {
        guard clip.isPlainTextClipboardCapture, isLikelyEnglishText(clip.content) else { return }
        refreshClipboardReading(for: clip.id)
    }

    private func showOverlayToast(message: String) {
        overlayToastTask?.cancel()
        overlayToast = OverlayToast(message: message)
        overlayToastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.overlayToast = nil
            }
        }
    }

    private func persistClipboardReading(id: String, payload: ClipboardReadingPayload) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            let data = try JSONEncoder().encode(payload)
            clip.readingPayloadJSON = String(decoding: data, as: UTF8.self)
            if clip.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLikelyEnglishText(clip.content) {
                clip.aiSummary = payload.summaryChinese
            }
            if !payload.titleChinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, isLikelyEnglishText(clip.title) {
                clip.title = payload.titleChinese
            }
            clip.refreshSearchText()
            try database.saveClip(clip)
            scheduleSemanticIndexRefresh(for: clip)
            try reloadClips()
            synchronizeAISearchResults(updatedClip: clip)
            if selectedClipID == clip.id {
                selectedClipID = clip.id
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func migrateLegacyShortcutDefaultsIfNeeded() throws {
        guard
            settings.shortcuts.openRecallOverlay == .openRecallOverlayDefault,
            settings.shortcuts.captureClipboard == .legacyCaptureClipboardDefault
        else {
            return
        }

        settings.shortcuts.captureClipboard = .captureClipboardDefault
        try database.saveSettings(settings)
    }

    private func preferredReasoningProfile() -> ProviderProfile? {
        if let defaultID = settings.defaultReasoningProfileID,
           let profile = providerProfiles.first(where: { $0.id == defaultID && $0.enabled && !(providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return profile
        }
        return providerProfiles.first(where: { $0.enabled && !(providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    private func preferredEmbeddingProfile() -> ProviderProfile? {
        if let defaultID = settings.defaultEmbeddingProfileID,
           let profile = providerProfiles.first(where: {
               $0.id == defaultID &&
               $0.supportsEmbeddings &&
               !((providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
           }) {
            return profile
        }
        return providerProfiles.first(where: {
            $0.supportsEmbeddings &&
            !((providerSecrets[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        })
    }

    private func resetAISearchState() {
        searchDebounceTask?.cancel()
        aiSearchTask?.cancel()
        aiSearchGeneration += 1
        activeSearchQuery = ""
        aiSearchResults = []
        aiSearchStatus = .idle
        aiSearchTrace = nil
        recallHighlightedResultID = nil
        if let selectedClipID, !clips.contains(where: { $0.id == selectedClipID }) {
            self.selectedClipID = clips.first?.id
        }
    }

    private func refreshAISearchIfNeeded() {
        invalidateSearchCaches()
        guard !activeSearchQuery.isEmpty else { return }
        searchDraft = activeSearchQuery
        Task { [weak self] in
            guard let self else { return }
            await self.beginAISearch(query: self.activeSearchQuery, trigger: .submitted)
        }
    }

    private func synchronizeAISearchResults(updatedClip: ClipItem? = nil, removedClipIDs: Set<String> = []) {
        guard !aiSearchResults.isEmpty else { return }

        var nextResults = aiSearchResults.filter { !removedClipIDs.contains($0.clip.id) }
        if let updatedClip, let index = nextResults.firstIndex(where: { $0.clip.id == updatedClip.id }) {
            nextResults[index].clip = updatedClip
        }
        aiSearchResults = nextResults
        if let recallHighlightedResultID, !nextResults.contains(where: { $0.id == recallHighlightedResultID }) {
            self.recallHighlightedResultID = nil
        }

        if let selectedClipID, removedClipIDs.contains(selectedClipID) {
            self.selectedClipID = displayedClips.first?.id
        }
    }

    private func invalidateSearchCaches(includingRewrite: Bool = false) {
        localCandidateCache.removeAll()
        queryEmbeddingCache.removeAll()
        if includingRewrite {
            queryRewriteCache.removeAll()
        }
    }

    private func recordSearchSelection(for clip: ClipItem) {
        guard !activeSearchQuery.isEmpty else { return }
        guard aiSearchResults.contains(where: { $0.clip.id == clip.id }) else { return }
        learnPlatformAlias(from: activeSearchQuery, clip: clip)
    }

    private func learnPlatformAlias(from query: String, clip: ClipItem) {
        guard clip.platformBucket != .otherWeb else { return }
        let normalized = SemanticSearchToolkit.normalizedLookup(query)
        guard normalized.count >= 2, normalized.count <= 12, !normalized.contains(" "), !normalized.contains("/") else { return }

        let knownAliases = Set(([clip.platformBucket.rawValue, clip.platformBucket.title] + clip.platformBucket.searchAliases).map(SemanticSearchToolkit.normalizedLookup))
        guard !knownAliases.contains(normalized) else { return }

        do {
            try database.upsertSearchAlias(
                canonical: clip.platformBucket.rawValue,
                entityType: .learned,
                alias: normalized
            )
            searchAliasRules = try database.fetchSearchAliasRules()
            invalidateSearchCaches(includingRewrite: true)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func scheduleSemanticIndexRefresh(for clip: ClipItem) {
        invalidateSearchCaches()
        guard let profile = preferredEmbeddingProfile(), let apiKey = providerSecrets[profile.id] else { return }
        semanticIndexTaskKey = nil
        Task { [weak self] in
            try? await self?.indexClipIfNeeded(clip, profile: profile, apiKey: apiKey)
        }
    }

    private func scheduleSemanticIndexBackfillIfNeeded() {
        guard let profile = preferredEmbeddingProfile(),
              let apiKey = providerSecrets[profile.id],
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        let clipsToIndex = (try? database.fetchNonTrashClips()) ?? []
        guard !clipsToIndex.isEmpty else { return }
        semanticIndexTaskKey = nil
        Task { [weak self] in
            try? await self?.ensureSemanticIndex(for: clipsToIndex, profile: profile, apiKey: apiKey)
        }
    }

    private func cachedQueryRewrite(for query: String) -> QueryRewrite {
        let cacheKey = SemanticSearchToolkit.normalizedLookup(query)
        if let cached = queryRewriteCache[cacheKey] {
            return cached
        }

        let rewrite = SearchQueryRewriter.rewrite(
            query: query,
            aliasRules: searchAliasRules,
            now: .now,
            timeZone: .current
        )
        queryRewriteCache[cacheKey] = rewrite
        return rewrite
    }

    private func cachedLocalCandidates(for query: String, rewrite: QueryRewrite, clips: [ClipItem]) -> [SearchCandidate] {
        let cacheKey = rewrite.normalizedQuery
        if let cached = localCandidateCache[cacheKey] {
            return cached
        }

        let filtered = clipsMatchingHardConstraints(clips: clips, rewrite: rewrite)
        let clipLookup = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        let scoredCandidates = filtered.map { SearchScorer.candidate(for: $0, rewrite: rewrite) }
        let candidates = scoredCandidates
            .filter { candidate in
                candidate.exactScore > 0 ||
                candidate.aliasScore >= 0.08 ||
                candidate.lexicalScore >= 0.08 ||
                candidate.taxonomyScore >= 0.08 ||
                candidate.localScore >= 0.10
            }
            .sorted { left, right in
                if left.localScore == right.localScore,
                   let leftClip = clipLookup[left.clipID],
                   let rightClip = clipLookup[right.clipID] {
                    return clipSort(leftClip, rightClip)
                }
                return left.localScore > right.localScore
            }

        localCandidateCache[cacheKey] = candidates
        return candidates
    }

    private func cachedQueryEmbedding(text: String, profile: ProviderProfile, apiKey: String) async throws -> [Double] {
        let cacheKey = "\(profile.id)|\(profile.embeddingModel)|\(SemanticSearchToolkit.normalizedLookup(text))"
        if let cached = queryEmbeddingCache[cacheKey] {
            return cached
        }

        let vector = try await embeddingService.embed(
            texts: [text],
            profile: profile,
            apiKey: apiKey
        ).first ?? []
        queryEmbeddingCache[cacheKey] = vector
        return vector
    }

    private func clipsMatchingHardConstraints(clips: [ClipItem], rewrite: QueryRewrite) -> [ClipItem] {
        var filtered = clips

        let platformHints = Set(rewrite.canonicalEntities.compactMap(PlatformBucket.init(rawValue:)))
        if !platformHints.isEmpty {
            let scoped = filtered.filter { platformHints.contains($0.platformBucket) }
            if !scoped.isEmpty {
                filtered = scoped
            }
        }

        let domainHints = rewrite.canonicalEntities.filter { $0.contains(".") }
        if !domainHints.isEmpty {
            let scoped = filtered.filter { clip in
                let domain = SemanticSearchToolkit.normalizedLookup(clip.domain)
                let url = SemanticSearchToolkit.normalizedLookup(clip.url)
                return domainHints.contains(where: { domain.contains($0) || url.contains($0) })
            }
            if !scoped.isEmpty {
                filtered = scoped
            }
        }

        if let timeRange = rewrite.timeRange {
            let scoped = filtered.filter { timeRange.contains($0.capturedAt) }
            if !scoped.isEmpty {
                filtered = scoped
            }
        }

        return filtered
    }

    private func localResults(
        from candidates: [SearchCandidate],
        clipLookup: [String: ClipItem],
        limit: Int = 24
    ) -> [AISearchResult] {
        candidates.prefix(limit).compactMap { candidate in
            guard let clip = clipLookup[candidate.clipID] else { return nil }
            return AISearchResult(
                clip: clip,
                score: min(0.88, candidate.localScore),
                matchedSnippet: candidate.matchedSnippet,
                source: .lexicalFallback,
                matchedFields: candidate.matchedFields
            )
        }
    }

    private func runAISearch(query: String, generation: Int, trigger: SearchExecutionTrigger) async {
        guard !isStaleSearchGeneration(generation) else { return }

        let overallStart = Date()
        let allClips = (try? database.fetchNonTrashClips()) ?? []
        guard !allClips.isEmpty else {
            aiSearchResults = []
            aiSearchStatus = .complete("No clips are available yet.")
            aiSearchTrace = SearchTraceV2(fallbackReason: "no_clips")
            return
        }

        var trace = SearchTraceV2()
        let rewriteStart = Date()
        let rewrite = cachedQueryRewrite(for: query)
        trace.stageLatencies["local_rewrite_ms"] = Date().timeIntervalSince(rewriteStart) * 1000
        trace.candidateCounts["all_clips"] = allClips.count

        let localStart = Date()
        let clipLookup = Dictionary(uniqueKeysWithValues: allClips.map { ($0.id, $0) })
        let localCandidates = cachedLocalCandidates(for: query, rewrite: rewrite, clips: allClips)
        trace.stageLatencies["local_recall_ms"] = Date().timeIntervalSince(localStart) * 1000
        trace.candidateCounts["local_candidates"] = localCandidates.count
        let fastResults = localResults(from: localCandidates, clipLookup: clipLookup)
        guard !isStaleSearchGeneration(generation) else { return }
        aiSearchResults = fastResults
        aiSearchTrace = trace
        syncSelectedClipToDisplayedResults()

        guard let embeddingProfile = preferredEmbeddingProfile(),
              let embeddingKey = providerSecrets[embeddingProfile.id],
              !embeddingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            guard !isStaleSearchGeneration(generation) else { return }
            aiSearchResults = fastResults
            trace.fallbackReason = "embedding_unavailable"
            trace.stageLatencies["total_ms"] = Date().timeIntervalSince(overallStart) * 1000
            aiSearchTrace = trace
            aiSearchStatus = searchMode == .semanticUnavailable
                ? .semanticUnavailable("AI search is configured incompletely, so Cosmogony is showing fast local recall results.")
                : .lexicalFallback("AI search is not fully configured yet, so Cosmogony is showing fast local recall results.")
            syncSelectedClipToDisplayedResults()
            return
        }

        if trigger == .typing {
            aiSearchStatus = .searching("Local matches are ready. Deep semantic reranking is continuing...")
            try? await Task.sleep(for: .milliseconds(520))
        }
        guard !isStaleSearchGeneration(generation) else { return }
        aiSearchStatus = .searching("Searching semantic evidence and reranking candidates...")

        let reasoningProfile = preferredReasoningProfile()
        let reasoningKey = reasoningProfile.flatMap { providerSecrets[$0.id] }
        let shouldUseRemoteIntent = trigger == .submitted || rewrite.confidence < 0.78
        var intent = SearchIntent(queryRewrite: rewrite)
        if shouldUseRemoteIntent {
            let remoteIntentStart = Date()
            let remoteIntent = await aiQueryIntentService.parseIntent(
                query: query,
                now: .now,
                timeZone: .current,
                profile: reasoningProfile,
                apiKey: reasoningKey
            )
            trace.stageLatencies["remote_intent_ms"] = Date().timeIntervalSince(remoteIntentStart) * 1000
            intent = intent.merged(with: remoteIntent)
        }

        do {
            let outcome = try await semanticResults(
                for: query,
                rewrite: rewrite,
                intent: intent,
                clips: allClips,
                localCandidates: localCandidates,
                embeddingProfile: embeddingProfile,
                embeddingKey: embeddingKey,
                reasoningProfile: reasoningProfile,
                reasoningKey: reasoningKey,
                trigger: trigger
            )
            guard !isStaleSearchGeneration(generation) else { return }
            aiSearchResults = outcome.results
            trace.stageLatencies.merge(outcome.trace.stageLatencies) { _, new in new }
            trace.candidateCounts.merge(outcome.trace.candidateCounts) { _, new in new }
            trace.fallbackReason = outcome.trace.fallbackReason
            trace.finalRankingReasons = outcome.trace.finalRankingReasons
            trace.stageLatencies["total_ms"] = Date().timeIntervalSince(overallStart) * 1000
            aiSearchTrace = trace
            if outcome.semanticHitCount > 0 {
                aiSearchStatus = .complete("Fast local recall was refined with semantic evidence and reranking.")
            } else {
                aiSearchStatus = .lexicalFallback("Semantic evidence was weak, so Cosmogony kept the stronger local recall ranking.")
            }
            syncSelectedClipToDisplayedResults()
        } catch {
            guard !isStaleSearchGeneration(generation) else { return }
            aiSearchResults = fastResults
            trace.fallbackReason = "semantic_failed: \(error.localizedDescription)"
            trace.stageLatencies["total_ms"] = Date().timeIntervalSince(overallStart) * 1000
            aiSearchTrace = trace
            aiSearchStatus = .failed("AI search enhancement failed, so Cosmogony kept the fast local results.")
            syncSelectedClipToDisplayedResults()
        }
    }

    private func ensureSemanticIndex(for clips: [ClipItem], profile: ProviderProfile, apiKey: String) async throws {
        let taskKey = "\(profile.id)|\(profile.embeddingModel)"
        if semanticIndexTaskKey == taskKey, let semanticIndexTask {
            try await semanticIndexTask.value
            return
        }

        semanticIndexTaskKey = taskKey
        semanticIndexTask = Task { [database, embeddingService] in
            for clip in clips {
                try Task.checkCancellation()
                let semanticSource = SearchDocumentBuilder.build(clip: clip).semanticText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !semanticSource.isEmpty else {
                    try database.deleteSearchChunks(clipID: clip.id)
                    continue
                }

                let chunks = SemanticSearchToolkit.chunkedContent(from: semanticSource)
                guard !chunks.isEmpty else {
                    try database.deleteSearchChunks(clipID: clip.id)
                    continue
                }

                let currentHash = SemanticSearchToolkit.contentHash(for: semanticSource)
                let existing = try database.fetchSearchChunks(
                    clipID: clip.id,
                    profileID: profile.id,
                    modelID: profile.embeddingModel
                )
                if !existing.isEmpty, existing.allSatisfy({ $0.contentHash == currentHash }) {
                    continue
                }

                let embeddings = try await embeddingService.embed(texts: chunks, profile: profile, apiKey: apiKey)
                let records = zip(chunks.indices, zip(chunks, embeddings)).map { index, pair in
                    let (chunkText, vector) = pair
                    return ClipSearchChunk(
                        clipID: clip.id,
                        chunkIndex: index,
                        chunkText: chunkText,
                        embeddingJSON: encodeDoubleArray(vector),
                        contentHash: currentHash,
                        profileID: profile.id,
                        modelID: profile.embeddingModel
                    )
                }
                try database.replaceSearchChunks(
                    records,
                    clipID: clip.id,
                    profileID: profile.id,
                    modelID: profile.embeddingModel
                )
            }
        }

        defer {
            semanticIndexTask = nil
        }
        try await semanticIndexTask?.value
    }

    private func indexClipIfNeeded(_ clip: ClipItem, profile: ProviderProfile, apiKey: String) async throws {
        let semanticSource = SearchDocumentBuilder.build(clip: clip).semanticText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !semanticSource.isEmpty else {
            try database.deleteSearchChunks(clipID: clip.id)
            return
        }

        let chunks = SemanticSearchToolkit.chunkedContent(from: semanticSource)
        guard !chunks.isEmpty else { return }

        let currentHash = SemanticSearchToolkit.contentHash(for: semanticSource)
        let existing = try database.fetchSearchChunks(
            clipID: clip.id,
            profileID: profile.id,
            modelID: profile.embeddingModel
        )
        if !existing.isEmpty, existing.allSatisfy({ $0.contentHash == currentHash }) {
            return
        }

        let embeddings = try await embeddingService.embed(texts: chunks, profile: profile, apiKey: apiKey)
        let records = zip(chunks.indices, zip(chunks, embeddings)).map { index, pair in
            let (chunkText, vector) = pair
            return ClipSearchChunk(
                clipID: clip.id,
                chunkIndex: index,
                chunkText: chunkText,
                embeddingJSON: encodeDoubleArray(vector),
                contentHash: currentHash,
                profileID: profile.id,
                modelID: profile.embeddingModel
            )
        }
        try database.replaceSearchChunks(
            records,
            clipID: clip.id,
            profileID: profile.id,
            modelID: profile.embeddingModel
        )
    }

    private func semanticResults(
        for query: String,
        rewrite: QueryRewrite,
        intent: SearchIntent,
        clips: [ClipItem],
        localCandidates: [SearchCandidate],
        embeddingProfile: ProviderProfile,
        embeddingKey: String,
        reasoningProfile: ProviderProfile?,
        reasoningKey: String?,
        trigger: SearchExecutionTrigger
    ) async throws -> (results: [AISearchResult], semanticHitCount: Int, trace: SearchTraceV2) {
        let clipLookup = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        let candidateClipIDs = Array(localCandidates.prefix(48).map(\.clipID))
        var trace = SearchTraceV2()

        let fetchStart = Date()
        let storedChunks = try database.fetchSearchChunks(
            clipIDs: candidateClipIDs,
            profileID: embeddingProfile.id,
            modelID: embeddingProfile.embeddingModel
        )
        trace.stageLatencies["chunk_fetch_ms"] = Date().timeIntervalSince(fetchStart) * 1000
        trace.candidateCounts["semantic_candidate_clips"] = candidateClipIDs.count
        trace.candidateCounts["semantic_candidate_chunks"] = storedChunks.count
        guard !storedChunks.isEmpty else {
            trace.fallbackReason = "no_indexed_chunks"
            return (localResults(from: localCandidates, clipLookup: clipLookup), 0, trace)
        }

        let queryText = intent.queryText.isEmpty ? (rewrite.queryText.isEmpty ? query : rewrite.queryText) : intent.queryText
        let embeddingStart = Date()
        let queryVector = try await cachedQueryEmbedding(text: queryText, profile: embeddingProfile, apiKey: embeddingKey)
        trace.stageLatencies["query_embedding_ms"] = Date().timeIntervalSince(embeddingStart) * 1000

        var mergedCandidates = Dictionary(uniqueKeysWithValues: localCandidates.map { ($0.clipID, $0) })
        var bestMatches: [String: (score: Double, chunkText: String)] = [:]
        for chunk in storedChunks {
            guard let clip = clipLookup[chunk.clipID],
                  var localCandidate = mergedCandidates[chunk.clipID]
            else {
                continue
            }

            let searchableSnippet = SemanticSearchToolkit.normalizedLookup(chunk.chunkText + " " + SearchDocumentBuilder.build(clip: clip).lookupText)
            if intent.excludedPhrases.contains(where: { !($0.isEmpty) && searchableSnippet.contains(SemanticSearchToolkit.normalizedLookup($0)) }) {
                continue
            }

            let similarity = SemanticSearchToolkit.cosineSimilarity(queryVector, chunk.embedding)
            var combinedScore = (similarity * 0.86) + min(0.12, localCandidate.localScore * 0.24)

            if !intent.requiredPhrases.isEmpty,
               intent.requiredPhrases.allSatisfy({ !searchableSnippet.contains(SemanticSearchToolkit.normalizedLookup($0)) }) {
                combinedScore -= 0.08
            }
            if intent.topics.contains(where: { searchableSnippet.contains(SemanticSearchToolkit.normalizedLookup($0)) }) {
                combinedScore += 0.04
            }
            if intent.synonyms.contains(where: { searchableSnippet.contains(SemanticSearchToolkit.normalizedLookup($0)) }) {
                combinedScore += 0.03
            }
            if let timeRange = intent.timeRange {
                if timeRange.contains(clip.capturedAt) {
                    combinedScore += 0.12
                } else {
                    let distanceDays = abs(clip.capturedAt.timeIntervalSince(timeRange.start)) / 86_400
                    combinedScore -= min(0.12, distanceDays / 120)
                }
            }

            if let existing = bestMatches[clip.id], existing.score >= combinedScore {
                continue
            }
            localCandidate.semanticScore = max(localCandidate.semanticScore, max(0, min(1, combinedScore)))
            localCandidate.matchedSnippet = SemanticSearchToolkit.bestSnippet(for: clip, matching: chunk.chunkText)
            if !localCandidate.matchedFields.contains(.semantic) {
                localCandidate.matchedFields.append(.semantic)
            }
            if !localCandidate.matchedFields.contains(.content) {
                localCandidate.matchedFields.append(.content)
            }
            mergedCandidates[clip.id] = localCandidate
            bestMatches[clip.id] = (combinedScore, chunk.chunkText)
        }

        let candidateMatches = bestMatches
            .filter { $0.value.score > 0.10 }
            .sorted { $0.value.score > $1.value.score }
            .prefix(20)

        let rerankCandidates = candidateMatches.compactMap { entry -> AIRerankCandidate? in
            guard let clip = clipLookup[entry.key] else { return nil }
            return AIRerankCandidate(
                clipID: clip.id,
                title: clip.title,
                url: clip.url,
                domain: clip.domain,
                capturedAt: clip.capturedAt,
                snippet: SemanticSearchToolkit.bestSnippet(for: clip, matching: entry.value.chunkText),
                vectorScore: max(0, min(1, entry.value.score))
            )
        }

        let rerankStart = Date()
        let rerankDecisions = await aiRerankService.rerank(
            query: query,
            intent: intent,
            candidates: rerankCandidates,
            profile: trigger == .submitted || rewrite.confidence < 0.78 ? reasoningProfile : nil,
            apiKey: trigger == .submitted || rewrite.confidence < 0.78 ? reasoningKey : nil
        )
        trace.stageLatencies["rerank_ms"] = Date().timeIntervalSince(rerankStart) * 1000
        let decisionLookup = Dictionary(uniqueKeysWithValues: rerankDecisions.map { ($0.clipID, $0) })

        for candidate in rerankCandidates {
            guard var localCandidate = mergedCandidates[candidate.clipID] else { continue }
            let decision = decisionLookup[candidate.clipID]
            localCandidate.semanticScore = max(localCandidate.semanticScore, decision?.score ?? candidate.vectorScore)
            localCandidate.matchedSnippet = compactSummary(from: decision?.snippet.isEmpty == false ? decision?.snippet ?? candidate.snippet : candidate.snippet)
            if !localCandidate.matchedFields.contains(.semantic) {
                localCandidate.matchedFields.append(.semantic)
            }
            mergedCandidates[candidate.clipID] = localCandidate
        }

        let finalCandidates = mergedCandidates.values
            .filter { $0.localScore >= 0.10 || $0.semanticScore >= 0.12 }
            .sorted { left, right in
                if left.rankingScore == right.rankingScore,
                   let leftClip = clipLookup[left.clipID],
                   let rightClip = clipLookup[right.clipID] {
                    return clipSort(leftClip, rightClip)
                }
                return left.rankingScore > right.rankingScore
            }

        trace.candidateCounts["merged_candidates"] = finalCandidates.count
        let results = finalCandidates.prefix(24).compactMap { candidate -> AISearchResult? in
            guard let clip = clipLookup[candidate.clipID] else { return nil }
            let source: AISearchResultSource = candidate.semanticScore >= 0.16 ? .semantic : .lexicalFallback
            return AISearchResult(
                clip: clip,
                score: min(0.99, source == .semantic ? candidate.rankingScore : candidate.localScore),
                matchedSnippet: candidate.matchedSnippet.isEmpty ? compactSummary(from: clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary) : candidate.matchedSnippet,
                source: source,
                matchedFields: candidate.matchedFields.sorted { $0.label < $1.label }
            )
        }
        trace.finalRankingReasons = results.prefix(3).map {
            "\($0.clip.title): \(Int($0.score * 100))% via \($0.matchedFields.map(\.label).joined(separator: " / "))"
        }

        return (results, results.filter { $0.source == .semantic }.count, trace)
    }

    private func syncSelectedClipToDisplayedResults() {
        let visibleClips = displayedClips
        guard !visibleClips.isEmpty else {
            selectedClipID = nil
            return
        }
        if let selectedClipID, visibleClips.contains(where: { $0.id == selectedClipID }) {
            return
        }
        selectedClipID = visibleClips.first?.id
    }

    private func isStaleSearchGeneration(_ generation: Int) -> Bool {
        generation != aiSearchGeneration || Task.isCancelled
    }

    private func persistAIEnrichment(id: String, summary: String, category: String, tags: [String]) {
        do {
            guard var clip = try database.fetchClip(id: id) else { return }
            clip.aiSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedCategory.isEmpty {
                clip.category = normalizedCategory
            }
            let normalizedTags = normalizedOrderedTags(from: tags.joined(separator: ", "))
            if !normalizedTags.isEmpty {
                clip.tags = normalizedTags
            }
            let assignedSpace = resolveSpace(forTags: clip.tags)
            clip.spaceID = assignedSpace?.id
            clip.spaceName = assignedSpace?.name ?? ""
            clip.refreshSearchText()
            try database.saveClip(clip)
            scheduleSemanticIndexRefresh(for: clip)
            try reloadClips()
            try reloadStats()
            selectedClipID = clip.id
            clipEditorHasUnsavedChanges = false
            refreshAISearchIfNeeded()
        } catch {
            statusMessage = "Saving AI analysis failed: \(error.localizedDescription)"
        }
    }
}
