import CosmogonyCore
import Foundation

@main
struct CosmogonyChecks {
    static func main() async {
        do {
            try verifyPlatforms()
            try verifyTimebox()
            try verifyProviders()
            try verifyShortcuts()
            try await verifyRecallOverlayStateFlow()
            try await verifyTodoOverlayStateFlow()
            try await verifyPromptLibraryStateFlow()
            try verifyChineseTextDetection()
            try verifyClipboardReadingHelpers()
            try verifySiteIconResolver()
            try verifySemanticChunking()
            try verifyQueryRewriteAliases()
            try verifyBilingualSearchDocument()
            try await verifyOilTubeAliasRecall()
            try await verifyChineseSummaryRecall()
            print("CosmogonyChecks: all checks passed.")
        } catch {
            fputs("CosmogonyChecks failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func verifyPlatforms() throws {
        try assert(PlatformClassifier.bucket(for: "https://x.com/openai/status/1") == .xPosts, "x.com should map to X帖子")
        try assert(PlatformClassifier.bucket(for: "https://mp.weixin.qq.com/s/abc") == .wechat, "WeChat should map to 微信公众号")
        try assert(PlatformClassifier.bucket(for: "https://youtu.be/demo") == .youtube, "youtu.be should map to YouTube")
        try assert(PlatformClassifier.bucket(for: "https://example.com") == .otherWeb, "Unknown hosts should map to 其余网页")
    }

    private static func verifyTimebox() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = TimeboxFilter.trailingHours(6)
        guard let interval = filter.interval(now: now) else {
            throw CheckError("Trailing hours should produce an interval")
        }
        try assert(abs(interval.duration - 21_600) < 0.1, "6h filter should equal 21600 seconds")
        try assert(filter.contains(now.addingTimeInterval(-3_600), now: now), "An item 1h old should be included")
        try assert(!filter.contains(now.addingTimeInterval(-30_000), now: now), "An item outside 6h should be excluded")
    }

    private static func verifyProviders() throws {
        var settings = AppSettings()
        let lexicalOnly = ProviderProfile(kind: .claude, displayName: "Claude", baseURL: "https://api.anthropic.com", defaultModel: "claude", embeddingModel: "")
        let embeddingReady = ProviderProfile(kind: .openAI, displayName: "OpenAI", baseURL: "https://api.openai.com", defaultModel: "gpt-4.1-mini", embeddingModel: "text-embedding-3-small")

        settings.defaultEmbeddingProfileID = lexicalOnly.id
        try assert(SearchScorer.mode(settings: settings, profiles: [lexicalOnly]) == .lexicalFallback, "Missing embedding model should fall back locally")

        settings.defaultEmbeddingProfileID = embeddingReady.id
        try assert(SearchScorer.mode(settings: settings, profiles: [lexicalOnly, embeddingReady]) == .semanticIndexReady, "Embedding profile should enable semantic search mode")
    }

    private static func verifyShortcuts() throws {
        let conflict = ShortcutSettings(
            openRecallOverlay: .openRecallOverlayDefault,
            captureClipboard: .openRecallOverlayDefault
        )
        try assert(conflict.conflictMessage() != nil, "Duplicate shortcuts must be rejected")

        let legacyJSON = """
        {
          "captureCurrentPage": {
            "keyCode": 1,
            "command": true,
            "shift": false,
            "option": false,
            "control": false
          },
          "captureClipboard": {
            "keyCode": 9,
            "command": false,
            "shift": true,
            "option": false,
            "control": true
          }
        }
        """
        let migrated = try JSONDecoder().decode(ShortcutSettings.self, from: Data(legacyJSON.utf8))
        try assert(migrated.openRecallOverlay.keyCode == 1, "Legacy captureCurrentPage shortcuts should migrate to openRecallOverlay")
        try assert(migrated.captureClipboard.keyCode == 9, "Clipboard shortcut should remain stable during migration")
    }

    private static func verifyRecallOverlayStateFlow() async throws {
        let model = try await MainActor.run {
            try AppModel.makeChecksModel()
        }

        try await MainActor.run {
            model.presentRecallOverlay()
            try assert(model.isRecallOverlayPresented, "Recall overlay should become visible when presented")
        }

        let highlightedID = try await MainActor.run { () -> String in
            guard let clip = model.checkClipForRecallFlow(matching: "openai") else {
                throw CheckError("Checks model should have at least one seeded clip")
            }
            let snippet = clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary
            let result = AISearchResult(clip: clip, score: 0.92, matchedSnippet: snippet, source: .semantic)
            model.injectRecallResultsForChecks(query: "openai", results: [result])
            model.setRecallHighlightedResult(result.id)
            return result.id
        }

        try await MainActor.run {
            let activationFlag = CheckFlag()
            model.activateBackstageHandler = {
                activationFlag.value = true
            }
            model.enterBackstageFromRecall()
            try assert(!model.isRecallOverlayPresented, "Entering backstage should hide the recall overlay")
            try assert(model.searchDraft == "openai", "Entering backstage should preserve the active recall query")
            try assert(model.selectedClipID == highlightedID, "Entering backstage should carry the highlighted result into the workspace")
            try assert(activationFlag.value, "Entering backstage should request workspace activation")
        }

        try await MainActor.run {
            model.presentRecallOverlay(resetSession: false)
            model.dismissRecallOverlay()
            try assert(!model.isRecallOverlayPresented, "Dismiss should hide the recall overlay")
            try assert(model.searchDraft.isEmpty, "Dismiss without backstage handoff should clear the recall query")
            try assert(model.recallResults.isEmpty, "Dismiss without backstage handoff should clear recall candidates")
        }
    }

    private static func verifyTodoOverlayStateFlow() async throws {
        let model = try await MainActor.run {
            try AppModel.makeChecksModel()
        }

        try await MainActor.run {
            model.presentRecallOverlay()
            try assert(model.overlayMode == .recall, "Recall overlay should still open in recall mode by default")

            model.searchDraft = "openai"
            model.todoDraft = "Polish overlay word cloud"
            model.cycleOverlayMode()
            try assert(model.overlayMode == .todo, "Tab-style cycling should switch the overlay into todo mode")
            try assert(model.searchDraft == "openai", "Switching to todo mode should preserve the recall draft")

            model.submitTodoDraft()
            try assert(model.todoItems.count == 1, "Submitting a todo draft should create one pending todo item")

            guard let created = model.todoItems.first else {
                throw CheckError("Todo item should exist after creation")
            }

            try assert(created.title == "Polish overlay word cloud", "Created todo should keep its submitted title")

            model.beginTodoEditing(created)
            model.todoEditingDraft = "Polish shared overlay word cloud"
            model.finishTodoEditing(commit: true)
            try assert(model.todoItems.first?.title == "Polish shared overlay word cloud", "Committing an edit should update the todo title")

            model.cycleOverlayMode()
            try assert(model.overlayMode == .promptLibrary, "Cycling from todo should now move into prompt library mode")
            model.cycleOverlayMode()
            try assert(model.overlayMode == .recall, "Cycling again should return to recall mode")
            try assert(model.searchDraft == "openai", "Returning to recall mode should keep the previous recall draft")

            model.cycleOverlayMode()
            try assert(model.overlayMode == .todo, "Cycling after recall should return to todo mode")
            guard let edited = model.todoItems.first else {
                throw CheckError("Edited todo should remain pending before completion")
            }
            model.completeTodo(edited.id)
            try assert(model.todoItems.isEmpty, "Completing a todo should remove it from the active todo cloud")
        }
    }

    private static func verifyPromptLibraryStateFlow() async throws {
        let model = try await MainActor.run {
            try AppModel.makeChecksModel()
        }

        try await MainActor.run {
            try assert(!model.promptItems.isEmpty, "Checks model should seed prompt library items")
            guard let firstPrompt = model.promptItems.first else {
                throw CheckError("Seeded prompt item should exist")
            }
            try assert(firstPrompt.isSystem, "Seeded prompts should be marked as system prompts")

            model.presentRecallOverlay(resetSession: false)
            model.setOverlayMode(.promptLibrary)
            try assert(model.overlayMode == .promptLibrary, "Overlay should support opening the prompt library mode")

            model.copyPromptLibraryContent(firstPrompt)
            try assert(model.overlayToast?.message == "已复制提示词", "Prompt copy should trigger an overlay toast")

            model.beginPromptRenaming(firstPrompt)
            model.promptRenamingDraft = "测试标题重命名"
            model.finishPromptRenaming(commit: true)
            try assert(model.promptItems.first(where: { $0.id == firstPrompt.id })?.title == "测试标题重命名", "Prompt rename should persist the new title")

            let activationFlag = CheckFlag()
            model.activateBackstageHandler = {
                activationFlag.value = true
            }
            model.enterBackstageForPromptLibrary(firstPrompt.id)
            try assert(model.backstageModule == .promptLibrary, "Cmd-click handoff should switch backstage into prompt library mode")
            try assert(model.selectedPromptID == firstPrompt.id, "Handoff should carry the selected prompt into backstage")
            try assert(activationFlag.value, "Prompt handoff should request workspace activation")
        }
    }

    private static func verifyChineseTextDetection() throws {
        try assert(CosmoTextClassifier.containsChinese("中文标题"), "Chinese text should be detected")
        try assert(!CosmoTextClassifier.containsChinese("Cosmogony Search"), "ASCII-only text should not be detected as Chinese")
    }

    private static func verifyClipboardReadingHelpers() throws {
        try assert(KeyCombination.captureClipboardDefault != KeyCombination.legacyCaptureClipboardDefault, "Clipboard shortcut default should move away from the legacy collision-prone combo")
        try assert(isLikelyEnglishText("This clipboard capture should be rendered as a bilingual reading card."), "English clipboard text should be detected")
        try assert(!isLikelyEnglishText("这是一个中文段落。"), "Chinese clipboard text should not be treated as English")
        let paragraphs = plainTextParagraphs(from: "First paragraph.\n\nSecond paragraph.")
        try assert(paragraphs.count == 2, "Blank lines should split plain text into reading paragraphs")
        try assert(clipboardDisplayTitle(from: String(repeating: "A", count: 120)).hasSuffix("..."), "Long clipboard titles should be truncated")
    }

    private static func verifySiteIconResolver() throws {
        try assert(SiteIconResolver.normalizedHost(from: "https://www.Example.com/path?q=1") == "example.com", "Hosts should be normalized and lowercase without www")
        try assert(SiteIconResolver.normalizedHost(from: "clipboard://local") == nil, "Non-web URLs should not produce a host")
        try assert(SiteIconResolver.fallbackIconURL(for: "example.com")?.absoluteString == "https://example.com/favicon.ico", "Fallback favicon URL should be stable")
    }

    private static func verifySemanticChunking() throws {
        let repeated = Array(repeating: "plugin architecture full text", count: 120).joined(separator: " ")
        let chunks = SemanticSearchToolkit.chunkedContent(from: repeated, targetLength: 300, overlap: 40)
        try assert(chunks.count >= 2, "Long text should be chunked into multiple semantic segments")
        try assert(SemanticSearchToolkit.contentHash(for: repeated) == SemanticSearchToolkit.contentHash(for: repeated), "Content hash should be stable")
    }

    private static func verifyQueryRewriteAliases() throws {
        let rewrite = SearchQueryRewriter.rewrite(
            query: "油管",
            aliasRules: SearchAliasRule.systemDefaults(),
            now: Date(timeIntervalSince1970: 1_700_000_000),
            timeZone: TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        )
        try assert(rewrite.canonicalEntities.contains("youtube"), "油管 should rewrite to youtube canonical entity")
        try assert(rewrite.aliases.contains(where: { $0.contains("youtube") }), "Rewrite aliases should include youtube")
    }

    private static func verifyBilingualSearchDocument() throws {
        let payload = ClipboardReadingPayload(
            detectedLanguage: "en",
            titleChinese: "OpenAI 官方频道",
            summaryChinese: "这是一个关于 YouTube 官方频道的中文摘要。",
            isPartial: false,
            paragraphs: []
        )
        let payloadData = try JSONEncoder().encode(payload)
        let clip = ClipItem(
            sourceType: .webPage,
            url: "https://www.youtube.com/@OpenAI",
            title: "OpenAI on YouTube",
            domain: "www.youtube.com",
            platformBucket: .youtube,
            capturedAt: .now,
            capturedHourBucket: floorToHour(.now),
            excerpt: "OpenAI official channel",
            content: "",
            aiSummary: "OpenAI 官方 YouTube 频道",
            category: "AI video",
            tags: ["youtube", "openai"],
            note: "",
            status: .library,
            readingPayloadJSON: String(decoding: payloadData, as: UTF8.self)
        )
        let document = SearchDocumentBuilder.build(clip: clip)
        try assert(document.lookupText.contains("油管"), "Lookup text should include platform aliases")
        try assert(document.lookupText.contains("官方频道"), "Lookup text should include Chinese reading payload text")
        try assert(document.semanticText.contains("Chinese summary"), "Semantic text should include metadata prefix")
    }

    private static func verifyOilTubeAliasRecall() async throws {
        let model = try await MainActor.run {
            try AppModel.makeChecksModel()
        }
        await MainActor.run {
            model.searchDraft = "油管"
        }
        await model.submitAISearch(forceImmediate: true)

        let results = await MainActor.run { model.aiSearchResults }
        try assert(!results.isEmpty, "油管 query should return results")
        try assert(results.first?.clip.platformBucket == .youtube, "油管 query should rank YouTube clips first")
        try assert(results.first?.matchedFields.contains(where: { $0 == .alias || $0 == .platform }) == true, "Oil-tube recall should explain alias/platform match")
    }

    private static func verifyChineseSummaryRecall() async throws {
        let model = try await MainActor.run {
            try AppModel.makeChecksModel()
        }
        await MainActor.run {
            model.searchDraft = "官方频道"
        }
        await model.submitAISearch(forceImmediate: true)

        let results = await MainActor.run { model.aiSearchResults }
        let trace = await MainActor.run { model.aiSearchTrace }
        try assert(results.contains(where: { $0.clip.platformBucket == .youtube }), "Chinese summary query should hit English-titled YouTube clips")
        try assert(trace?.stageLatencies["local_recall_ms"] != nil, "Search trace should record local recall latency")
        try assert(trace?.fallbackReason == "embedding_unavailable" || trace?.fallbackReason == "no_indexed_chunks" || (trace?.fallbackReason.isEmpty ?? false), "Trace should carry fallback context")
    }

    private static func assert(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else {
            throw CheckError(message)
        }
    }
}

private struct CheckError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

@MainActor
private final class CheckFlag {
    var value = false
}
