import Carbon
import Foundation
import GRDB

public enum ClipSourceType: String, Codable, CaseIterable, Sendable {
    case webPage = "web_page"
    case clipboard
}

public enum ClipStatus: String, Codable, CaseIterable, Sendable {
    case inbox
    case library
    case failed
    case trashed
}

public enum ClipScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case inbox
    case library
    case trash

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All Clips"
        case .inbox: "Inbox"
        case .library: "Library"
        case .trash: "Trash"
        }
    }
}

public enum PlatformBucket: String, Codable, CaseIterable, Identifiable, Sendable {
    case xPosts = "x_posts"
    case rednote = "xiaohongshu"
    case wechat = "wechat"
    case douyin = "douyin"
    case youtube = "youtube"
    case otherWeb = "other_web"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .xPosts: "X帖子"
        case .rednote: "小红书"
        case .wechat: "微信公众号"
        case .douyin: "抖音"
        case .youtube: "YouTube"
        case .otherWeb: "其余网页"
        }
    }

    public var searchAliases: [String] {
        switch self {
        case .xPosts:
            return ["x", "x.com", "twitter", "tweet", "tweets", "推特", "推文", "x 帖子"]
        case .rednote:
            return ["xiaohongshu", "rednote", "小红书", "红薯", "种草"]
        case .wechat:
            return ["wechat", "weixin", "微信", "公众号", "微信公众号"]
        case .douyin:
            return ["douyin", "抖音", "短视频"]
        case .youtube:
            return ["youtube", "you tube", "yt", "youtu.be", "油管", "优兔", "视频平台"]
        case .otherWeb:
            return ["网页", "web", "page", "site"]
        }
    }
}

public enum PlatformFilter: Equatable, Sendable {
    case all
    case bucket(PlatformBucket)
}

public enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case gemini
    case claude
    case minimax
    case deepseek
    case openAICompatible = "openai_compatible"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .gemini: "Gemini"
        case .claude: "Claude"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
        case .openAICompatible: "OpenAI-Compatible"
        }
    }

    public var suggestedBaseURL: String {
        switch self {
        case .openAI:
            "https://api.openai.com"
        case .gemini:
            "https://generativelanguage.googleapis.com"
        case .claude:
            "https://api.anthropic.com"
        case .minimax:
            "https://api.minimax.chat"
        case .deepseek:
            "https://api.deepseek.com"
        case .openAICompatible:
            ""
        }
    }
}

public enum SearchMode: String, Sendable {
    case lexicalFallback = "lexical_fallback"
    case semanticIndexReady = "semantic_index_ready"
    case semanticUnavailable = "semantic_unavailable"

    public var label: String {
        switch self {
        case .lexicalFallback: "Local lexical/taxonomy"
        case .semanticIndexReady: "AI semantic search"
        case .semanticUnavailable: "AI unavailable"
        }
    }
}

public struct ClipStats: Equatable, Sendable {
    public var totalCount: Int
    public var inboxCount: Int
    public var libraryCount: Int
    public var failedCount: Int
    public var trashCount: Int
    public var bucketCounts: [PlatformBucket: Int]

    public init(
        totalCount: Int = 0,
        inboxCount: Int = 0,
        libraryCount: Int = 0,
        failedCount: Int = 0,
        trashCount: Int = 0,
        bucketCounts: [PlatformBucket: Int] = [:]
    ) {
        self.totalCount = totalCount
        self.inboxCount = inboxCount
        self.libraryCount = libraryCount
        self.failedCount = failedCount
        self.trashCount = trashCount
        self.bucketCounts = bucketCounts
    }
}

public struct KeyCombination: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public static let openRecallOverlayDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_S), command: true, shift: true, option: false, control: false)
    public static let captureCurrentPageDefault = openRecallOverlayDefault
    public static let legacyCaptureClipboardDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_V), command: true, shift: true, option: false, control: false)
    public static let captureClipboardDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_V), command: false, shift: true, option: false, control: true)

    public init(keyCode: UInt32, command: Bool, shift: Bool, option: Bool, control: Bool) {
        self.keyCode = keyCode
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if command { value |= UInt32(cmdKey) }
        if shift { value |= UInt32(shiftKey) }
        if option { value |= UInt32(optionKey) }
        if control { value |= UInt32(controlKey) }
        return value
    }

    public var displayString: String {
        let glyphs = [
            control ? "^" : "",
            option ? "⌥" : "",
            shift ? "⇧" : "",
            command ? "⌘" : ""
        ].joined()
        return glyphs + keyCode.displayKey
    }
}

extension UInt32 {
    fileprivate var displayKey: String {
        switch self {
        case UInt32(kVK_ANSI_A): "A"
        case UInt32(kVK_ANSI_B): "B"
        case UInt32(kVK_ANSI_C): "C"
        case UInt32(kVK_ANSI_D): "D"
        case UInt32(kVK_ANSI_E): "E"
        case UInt32(kVK_ANSI_F): "F"
        case UInt32(kVK_ANSI_G): "G"
        case UInt32(kVK_ANSI_H): "H"
        case UInt32(kVK_ANSI_I): "I"
        case UInt32(kVK_ANSI_J): "J"
        case UInt32(kVK_ANSI_K): "K"
        case UInt32(kVK_ANSI_L): "L"
        case UInt32(kVK_ANSI_M): "M"
        case UInt32(kVK_ANSI_N): "N"
        case UInt32(kVK_ANSI_O): "O"
        case UInt32(kVK_ANSI_P): "P"
        case UInt32(kVK_ANSI_Q): "Q"
        case UInt32(kVK_ANSI_R): "R"
        case UInt32(kVK_ANSI_S): "S"
        case UInt32(kVK_ANSI_T): "T"
        case UInt32(kVK_ANSI_U): "U"
        case UInt32(kVK_ANSI_V): "V"
        case UInt32(kVK_ANSI_W): "W"
        case UInt32(kVK_ANSI_X): "X"
        case UInt32(kVK_ANSI_Y): "Y"
        case UInt32(kVK_ANSI_Z): "Z"
        case UInt32(kVK_Space): "Space"
        case UInt32(kVK_Return): "Return"
        default: "Key\(self)"
        }
    }
}

public enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case openRecallOverlay
    case captureClipboard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openRecallOverlay: "唤起 Recall 蒙版"
        case .captureClipboard: "剪藏剪贴板"
        }
    }
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public var openRecallOverlay: KeyCombination = .openRecallOverlayDefault
    public var captureClipboard: KeyCombination = .captureClipboardDefault

    public init(
        openRecallOverlay: KeyCombination = .openRecallOverlayDefault,
        captureClipboard: KeyCombination = .captureClipboardDefault
    ) {
        self.openRecallOverlay = openRecallOverlay
        self.captureClipboard = captureClipboard
    }

    public func conflictMessage() -> String? {
        guard openRecallOverlay == captureClipboard else { return nil }
        return "两个全局快捷键不能相同。"
    }

    private enum CodingKeys: String, CodingKey {
        case openRecallOverlay
        case captureClipboard
        case captureCurrentPage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        openRecallOverlay =
            try container.decodeIfPresent(KeyCombination.self, forKey: .openRecallOverlay) ??
            container.decodeIfPresent(KeyCombination.self, forKey: .captureCurrentPage) ??
            .openRecallOverlayDefault
        captureClipboard =
            try container.decodeIfPresent(KeyCombination.self, forKey: .captureClipboard) ??
            .captureClipboardDefault
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(openRecallOverlay, forKey: .openRecallOverlay)
        try container.encode(captureClipboard, forKey: .captureClipboard)
    }
}

public struct CaptureSettings: Codable, Equatable, Sendable {
    public var enrichPublicPages = true
    public var preferBridgeRichCapture = true
    public var maxStoredCharacters = 80_000

    public init(enrichPublicPages: Bool = true, preferBridgeRichCapture: Bool = true, maxStoredCharacters: Int = 80_000) {
        self.enrichPublicPages = enrichPublicPages
        self.preferBridgeRichCapture = preferBridgeRichCapture
        self.maxStoredCharacters = maxStoredCharacters
    }
}

public struct StorageSettings: Codable, Equatable, Sendable {
    public var openAtLogin = false

    public init(openAtLogin: Bool = false) {
        self.openAtLogin = openAtLogin
    }
}

public enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system:
            "Follow System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    public var description: String {
        switch self {
        case .system:
            "让应用跟随 macOS 当前外观。"
        case .light:
            "固定使用浅色界面。"
        case .dark:
            "固定使用深色界面。"
        }
    }
}

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case appearance
    case providers
    case shortcuts
    case capture
    case storage

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .appearance:
            "Appearance"
        case .providers:
            "Providers"
        case .shortcuts:
            "Shortcuts"
        case .capture:
            "Capture"
        case .storage:
            "Storage"
        }
    }

    public var systemImage: String {
        switch self {
        case .appearance:
            "circle.lefthalf.filled"
        case .providers:
            "brain.head.profile"
        case .shortcuts:
            "command"
        case .capture:
            "square.and.arrow.down"
        case .storage:
            "internaldrive"
        }
    }
}

public enum AppOverlay: String, Identifiable, Sendable {
    case clipDetail

    public var id: String { rawValue }
}

public enum OverlayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case recall
    case todo
    case promptLibrary

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recall:
            "Recall"
        case .todo:
            "Todo"
        case .promptLibrary:
            "Prompts"
        }
    }
}

public enum BackstageModule: String, Codable, CaseIterable, Identifiable, Sendable {
    case clips
    case todo
    case promptLibrary
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clips:
            "Clips"
        case .todo:
            "Todo"
        case .promptLibrary:
            "Prompt Library"
        case .settings:
            "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .clips:
            return "square.stack.3d.up"
        case .todo:
            return "checklist"
        case .promptLibrary:
            return "text.badge.star"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

public struct OverlayToast: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var defaultReasoningProfileID: String?
    public var defaultEmbeddingProfileID: String?
    public var appearance: AppAppearance = .system
    public var shortcuts = ShortcutSettings()
    public var capture = CaptureSettings()
    public var storage = StorageSettings()
    public var bridgeToken: String?

    public init(
        defaultReasoningProfileID: String? = nil,
        defaultEmbeddingProfileID: String? = nil,
        appearance: AppAppearance = .system,
        shortcuts: ShortcutSettings = ShortcutSettings(),
        capture: CaptureSettings = CaptureSettings(),
        storage: StorageSettings = StorageSettings(),
        bridgeToken: String? = nil
    ) {
        self.defaultReasoningProfileID = defaultReasoningProfileID
        self.defaultEmbeddingProfileID = defaultEmbeddingProfileID
        self.appearance = appearance
        self.shortcuts = shortcuts
        self.capture = capture
        self.storage = storage
        self.bridgeToken = bridgeToken
    }
}

public struct CategoryRule: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "category_rules"

    public var id: String
    public var canonical: String
    public var aliases: [String]
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, canonical: String, aliases: [String], updatedAt: Date = .now) {
        self.id = id
        self.canonical = canonical
        self.aliases = aliases
        self.updatedAt = updatedAt
    }

    public init(row: Row) {
        id = row["id"]
        canonical = row["canonical"]
        aliases = decodeStringArray(row["aliases_json"] ?? "[]")
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["canonical"] = canonical
        container["aliases_json"] = encodeStringArray(aliases)
        container["updated_at"] = updatedAt.timeIntervalSince1970
    }
}

public struct Space: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "spaces"

    public var id: String
    public var name: String
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        tags: [String],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(row: Row) {
        id = row["id"]
        name = row["name"] ?? ""
        tags = decodeStringArray(row["tags_json"] ?? "[]")
        createdAt = Date(timeIntervalSince1970: row["created_at"] ?? Date().timeIntervalSince1970)
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["tags_json"] = encodeStringArray(tags)
        container["created_at"] = createdAt.timeIntervalSince1970
        container["updated_at"] = updatedAt.timeIntervalSince1970
    }
}

public struct TodoItem: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "todo_items"

    public var id: String
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var visualSeed: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil,
        visualSeed: Int = Int.random(in: 0...999_999)
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.visualSeed = visualSeed
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public init(row: Row) {
        id = row["id"]
        title = row["title"] ?? ""
        createdAt = Date(timeIntervalSince1970: row["created_at"] ?? Date().timeIntervalSince1970)
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
        if let completedAtValue: Double = row["completed_at"] {
            completedAt = Date(timeIntervalSince1970: completedAtValue)
        } else {
            completedAt = nil
        }
        visualSeed = Int(row["visual_seed"] ?? 0)
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["created_at"] = createdAt.timeIntervalSince1970
        container["updated_at"] = updatedAt.timeIntervalSince1970
        container["completed_at"] = completedAt?.timeIntervalSince1970
        container["visual_seed"] = visualSeed
    }
}

public struct PromptLibraryItem: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "prompt_library_items"

    public var id: String
    public var title: String
    public var content: String
    public var sourceLabel: String
    public var sourceURL: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isSystem: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        sourceLabel: String = "",
        sourceURL: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isSystem: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceLabel = sourceLabel
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSystem = isSystem
    }

    public var previewText: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 170 else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 170)
        return String(trimmed[..<index]) + "…"
    }

    public init(row: Row) {
        id = row["id"]
        title = row["title"] ?? ""
        content = row["content"] ?? ""
        sourceLabel = row["source_label"] ?? ""
        sourceURL = row["source_url"] ?? ""
        createdAt = Date(timeIntervalSince1970: row["created_at"] ?? Date().timeIntervalSince1970)
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
        isSystem = row["is_system"] ?? false
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["content"] = content
        container["source_label"] = sourceLabel
        container["source_url"] = sourceURL
        container["created_at"] = createdAt.timeIntervalSince1970
        container["updated_at"] = updatedAt.timeIntervalSince1970
        container["is_system"] = isSystem
    }
}

public struct ProviderProfile: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "provider_profiles"

    public var id: String
    public var kind: ProviderKind
    public var displayName: String
    public var apiKeyRef: String
    public var baseURL: String
    public var defaultModel: String
    public var embeddingModel: String
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        kind: ProviderKind = .openAI,
        displayName: String = "New Provider",
        apiKeyRef: String = UUID().uuidString,
        baseURL: String = "",
        defaultModel: String = "gpt-4.1-mini",
        embeddingModel: String = "",
        enabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.apiKeyRef = apiKeyRef
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.embeddingModel = embeddingModel
        self.enabled = enabled
    }

    public var supportsEmbeddings: Bool {
        enabled && !embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var resolvedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.suggestedBaseURL : trimmed
    }

    public init(row: Row) {
        id = row["id"]
        kind = ProviderKind(rawValue: row["kind"] ?? "") ?? .openAICompatible
        displayName = row["display_name"] ?? ""
        apiKeyRef = row["api_key_ref"] ?? ""
        baseURL = row["base_url"] ?? ""
        defaultModel = row["default_model"] ?? ""
        embeddingModel = row["embedding_model"] ?? ""
        enabled = row["enabled"] ?? true
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["kind"] = kind.rawValue
        container["display_name"] = displayName
        container["api_key_ref"] = apiKeyRef
        container["base_url"] = baseURL
        container["default_model"] = defaultModel
        container["embedding_model"] = embeddingModel
        container["enabled"] = enabled
    }
}

public struct ClipItem: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "clip_items"

    public var id: String
    public var sourceType: ClipSourceType
    public var url: String
    public var title: String
    public var domain: String
    public var platformBucket: PlatformBucket
    public var capturedAt: Date
    public var capturedHourBucket: Date
    public var excerpt: String
    public var content: String
    public var aiSummary: String
    public var category: String
    public var tags: [String]
    public var spaceID: String?
    public var spaceName: String
    public var note: String
    public var status: ClipStatus
    public var isPinned: Bool
    public var trashedAt: Date?
    public var readingPayloadJSON: String
    public var searchText: String

    public init(
        id: String = UUID().uuidString,
        sourceType: ClipSourceType,
        url: String,
        title: String,
        domain: String,
        platformBucket: PlatformBucket,
        capturedAt: Date,
        capturedHourBucket: Date,
        excerpt: String,
        content: String,
        aiSummary: String,
        category: String,
        tags: [String],
        spaceID: String? = nil,
        spaceName: String = "",
        note: String,
        status: ClipStatus,
        isPinned: Bool = false,
        trashedAt: Date? = nil,
        readingPayloadJSON: String = ""
    ) {
        self.id = id
        self.sourceType = sourceType
        self.url = url
        self.title = title
        self.domain = domain
        self.platformBucket = platformBucket
        self.capturedAt = capturedAt
        self.capturedHourBucket = capturedHourBucket
        self.excerpt = excerpt
        self.content = content
        self.aiSummary = aiSummary
        self.category = category
        self.tags = tags
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.note = note
        self.status = status
        self.isPinned = isPinned
        self.trashedAt = trashedAt
        self.readingPayloadJSON = readingPayloadJSON
        self.searchText = ""
        self.searchText = SearchDocumentBuilder.build(clip: self).lookupText
    }

    public init(row: Row) {
        id = row["id"]
        sourceType = ClipSourceType(rawValue: row["source_type"] ?? "") ?? .webPage
        url = row["url"] ?? ""
        title = row["title"] ?? ""
        domain = row["domain"] ?? ""
        platformBucket = PlatformBucket(rawValue: row["platform_bucket"] ?? "") ?? .otherWeb
        capturedAt = Date(timeIntervalSince1970: row["captured_at"] ?? Date().timeIntervalSince1970)
        capturedHourBucket = Date(timeIntervalSince1970: row["captured_hour_bucket"] ?? Date().timeIntervalSince1970)
        excerpt = row["excerpt"] ?? ""
        content = row["content"] ?? ""
        aiSummary = row["ai_summary"] ?? ""
        category = row["category"] ?? ""
        tags = decodeStringArray(row["tags_json"] ?? "[]")
        spaceID = row["space_id"]
        spaceName = row["space_name"] ?? ""
        note = row["note"] ?? ""
        status = ClipStatus(rawValue: row["status"] ?? "") ?? .inbox
        isPinned = row["is_pinned"] ?? false
        if let trashedTimestamp: Double = row["trashed_at"] {
            trashedAt = Date(timeIntervalSince1970: trashedTimestamp)
        } else {
            trashedAt = nil
        }
        readingPayloadJSON = row["reading_payload_json"] ?? ""
        searchText = row["search_text"] ?? ""
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["source_type"] = sourceType.rawValue
        container["url"] = url
        container["title"] = title
        container["domain"] = domain
        container["platform_bucket"] = platformBucket.rawValue
        container["captured_at"] = capturedAt.timeIntervalSince1970
        container["captured_hour_bucket"] = capturedHourBucket.timeIntervalSince1970
        container["excerpt"] = excerpt
        container["content"] = content
        container["ai_summary"] = aiSummary
        container["category"] = category
        container["tags_json"] = encodeStringArray(tags)
        container["space_id"] = spaceID
        container["space_name"] = spaceName
        container["note"] = note
        container["status"] = status.rawValue
        container["is_pinned"] = isPinned
        container["trashed_at"] = trashedAt?.timeIntervalSince1970
        container["reading_payload_json"] = readingPayloadJSON
        container["search_text"] = searchText
    }

    public mutating func refreshSearchText() {
        searchText = SearchDocumentBuilder.build(clip: self).lookupText
    }

    public static func composeSearchText(
        title: String,
        domain: String,
        excerpt: String,
        content: String,
        category: String,
        tags: [String],
        spaceName: String,
        note: String
    ) -> String {
        [title, domain, excerpt, content, category, tags.joined(separator: " "), spaceName, note]
            .joined(separator: " ")
            .lowercased()
    }

    public var isPlainTextClipboardCapture: Bool {
        sourceType == .clipboard && (URL(string: url)?.scheme?.lowercased() == "clipboard")
    }

    public var readingPayload: ClipboardReadingPayload? {
        guard !readingPayloadJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = readingPayloadJSON.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(ClipboardReadingPayload.self, from: data)
    }
}

public struct ClipboardReadingParagraph: Codable, Equatable, Sendable {
    public var original: String
    public var translation: String

    public init(original: String, translation: String) {
        self.original = original
        self.translation = translation
    }
}

public struct ClipboardReadingPayload: Codable, Equatable, Sendable {
    public var detectedLanguage: String
    public var titleChinese: String
    public var summaryChinese: String
    public var isPartial: Bool
    public var paragraphs: [ClipboardReadingParagraph]

    public init(
        detectedLanguage: String,
        titleChinese: String,
        summaryChinese: String,
        isPartial: Bool,
        paragraphs: [ClipboardReadingParagraph]
    ) {
        self.detectedLanguage = detectedLanguage
        self.titleChinese = titleChinese
        self.summaryChinese = summaryChinese
        self.isPartial = isPartial
        self.paragraphs = paragraphs
    }
}

public enum TimeboxFilter: Equatable, Sendable {
    case all
    case trailingHours(Int)
    case day(Date)
    case range(Date, Date)

    public func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .all:
            return nil
        case let .trailingHours(hours):
            let clamped = max(1, hours)
            return DateInterval(start: now.addingTimeInterval(TimeInterval(-3600 * clamped)), end: now)
        case let .day(day):
            guard let interval = calendar.dateInterval(of: .day, for: day) else { return nil }
            return interval
        case let .range(start, end):
            return start <= end ? DateInterval(start: start, end: end) : DateInterval(start: end, end: start)
        }
    }

    public func contains(_ value: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(now: now, calendar: calendar) else { return true }
        return interval.contains(value)
    }

    public var summary: String {
        switch self {
        case .all:
            "All time"
        case let .trailingHours(hours):
            "Past \(hours)h"
        case let .day(day):
            day.formatted(date: .abbreviated, time: .omitted)
        case let .range(start, end):
            "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}

public enum TimeboxMode: String, CaseIterable, Identifiable, Sendable {
    case all
    case trailingHours
    case day
    case range

    public var id: String { rawValue }
}

public struct TimeboxDraft: Equatable, Sendable {
    public var mode: TimeboxMode = .all
    public var trailingHours = 24
    public var day: Date = .now
    public var rangeStart: Date = Calendar.current.date(byAdding: .hour, value: -24, to: .now) ?? .now
    public var rangeEnd: Date = .now

    public init(
        mode: TimeboxMode = .all,
        trailingHours: Int = 24,
        day: Date = .now,
        rangeStart: Date = Calendar.current.date(byAdding: .hour, value: -24, to: .now) ?? .now,
        rangeEnd: Date = .now
    ) {
        self.mode = mode
        self.trailingHours = trailingHours
        self.day = day
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }

    public static func today(now: Date = .now) -> TimeboxDraft {
        TimeboxDraft(
            mode: .day,
            trailingHours: 24,
            day: now,
            rangeStart: Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now,
            rangeEnd: now
        )
    }

    public var filter: TimeboxFilter {
        switch mode {
        case .all:
            .all
        case .trailingHours:
            .trailingHours(max(1, trailingHours))
        case .day:
            .day(day)
        case .range:
            .range(rangeStart, rangeEnd)
        }
    }
}

public enum PlatformClassifier {
    public static func bucket(for urlString: String) -> PlatformBucket {
        guard
            let host = URL(string: urlString)?.host?.lowercased()
        else {
            return .otherWeb
        }

        if host == "x.com" || host == "twitter.com" || host.hasSuffix(".x.com") || host.hasSuffix(".twitter.com") {
            return .xPosts
        }
        if host == "xiaohongshu.com" || host.hasSuffix(".xiaohongshu.com") {
            return .rednote
        }
        if host == "mp.weixin.qq.com" {
            return .wechat
        }
        if host == "douyin.com" || host == "iesdouyin.com" || host.hasSuffix(".douyin.com") || host.hasSuffix(".iesdouyin.com") {
            return .douyin
        }
        if host == "youtube.com" || host == "youtu.be" || host.hasSuffix(".youtube.com") {
            return .youtube
        }
        return .otherWeb
    }
}

public enum SearchScorer {
    public static func mode(settings: AppSettings, profiles: [ProviderProfile], providerSecrets: [String: String] = [:]) -> SearchMode {
        guard let id = settings.defaultEmbeddingProfileID else {
            return .lexicalFallback
        }
        guard let profile = profiles.first(where: { $0.id == id }) else {
            return .semanticUnavailable
        }
        guard profile.supportsEmbeddings else {
            return .lexicalFallback
        }
        guard !providerSecrets.isEmpty else {
            return .semanticIndexReady
        }
        let secret = (providerSecrets[profile.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return secret.isEmpty ? .semanticUnavailable : .semanticIndexReady
    }

    public static func score(_ clip: ClipItem, query: String) -> Int {
        let rewrite = SearchQueryRewriter.rewrite(
            query: query,
            aliasRules: SearchAliasRule.systemDefaults(),
            now: .now,
            timeZone: .current
        )
        return Int((candidate(for: clip, rewrite: rewrite).localScore * 100).rounded())
    }

    package static func candidate(for clip: ClipItem, rewrite: QueryRewrite, now: Date = .now) -> SearchCandidate {
        let document = SearchDocumentBuilder.build(clip: clip)
        guard !rewrite.normalizedQuery.isEmpty else {
            return SearchCandidate(clipID: clip.id, recencyScore: recencyScore(for: clip, now: now), matchedSnippet: fallbackSnippet(for: clip))
        }

        if rewrite.excludedTerms.contains(where: { !($0.isEmpty) && document.lookupText.contains($0) }) {
            return SearchCandidate(clipID: clip.id)
        }

        var lexicalScore = 0.0
        var aliasScore = 0.0
        var taxonomyScore = 0.0
        var exactScore = 0.0
        var matched = Set<SearchMatchedField>()

        let normalizedTitle = SemanticSearchToolkit.normalizedLookup(clip.title)
        let normalizedDomain = SemanticSearchToolkit.normalizedLookup(clip.domain)
        let normalizedURL = SemanticSearchToolkit.normalizedLookup(clip.url)
        let normalizedCategory = SemanticSearchToolkit.normalizedLookup(clip.category)
        let normalizedTags = clip.tags.map(SemanticSearchToolkit.normalizedLookup)
        let normalizedNote = SemanticSearchToolkit.normalizedLookup(clip.note)
        let normalizedSpace = SemanticSearchToolkit.normalizedLookup(clip.spaceName)
        let normalizedPlatform = SemanticSearchToolkit.normalizedLookup(clip.platformBucket.title)
        let chineseLookup = SemanticSearchToolkit.normalizedLookup([
            clip.readingPayload?.titleChinese ?? "",
            clip.readingPayload?.summaryChinese ?? ""
        ].joined(separator: " "))

        let query = rewrite.normalizedQuery
        if normalizedTitle == query || normalizedDomain == query || normalizedURL == query {
            exactScore += 0.65
            matched.insert(.exact)
        }
        if normalizedTitle.contains(query) {
            lexicalScore += 0.42
            matched.insert(.title)
        }
        if normalizedDomain.contains(query) {
            lexicalScore += 0.2
            matched.insert(.domain)
        }
        if normalizedURL.contains(query) {
            lexicalScore += 0.14
            matched.insert(.url)
        }
        if normalizedPlatform.contains(query) {
            aliasScore += 0.32
            matched.insert(.platform)
        }
        if document.aliasText.contains(query) {
            aliasScore += 0.48
            matched.insert(.alias)
        }
        if normalizedCategory.contains(query) {
            taxonomyScore += 0.3
            matched.insert(.category)
        }
        if normalizedTags.contains(where: { $0.contains(query) }) {
            taxonomyScore += 0.24
            matched.insert(.tag)
        }
        if normalizedNote.contains(query) {
            lexicalScore += 0.12
            matched.insert(.note)
        }
        if normalizedSpace.contains(query) {
            taxonomyScore += 0.14
            matched.insert(.space)
        }
        if document.summaryText.contains(query) {
            lexicalScore += 0.18
            matched.insert(.summary)
        }
        if !chineseLookup.isEmpty, chineseLookup.contains(query) {
            lexicalScore += 0.18
            matched.insert(.chineseSummary)
        }
        if document.contentText.contains(query) {
            lexicalScore += 0.16
            matched.insert(.content)
        }

        for term in rewrite.allTerms where term != query {
            if normalizedTitle.contains(term) {
                lexicalScore += 0.11
                matched.insert(.title)
            }
            if normalizedDomain.contains(term) {
                lexicalScore += 0.06
                matched.insert(.domain)
            }
            if normalizedURL.contains(term) {
                lexicalScore += 0.05
                matched.insert(.url)
            }
            if document.aliasText.contains(term) {
                aliasScore += 0.12
                matched.insert(.alias)
            }
            if normalizedCategory.contains(term) {
                taxonomyScore += 0.08
                matched.insert(.category)
            }
            if normalizedTags.contains(where: { $0.contains(term) }) {
                taxonomyScore += 0.08
                matched.insert(.tag)
            }
            if document.summaryText.contains(term) {
                lexicalScore += 0.07
                matched.insert(.summary)
            }
            if !chineseLookup.isEmpty, chineseLookup.contains(term) {
                lexicalScore += 0.08
                matched.insert(.chineseSummary)
            }
            if document.contentText.contains(term) {
                lexicalScore += 0.06
                matched.insert(.content)
            }
        }

        if !rewrite.requiredTerms.isEmpty {
            let requiredMatches = rewrite.requiredTerms.filter { document.lookupText.contains($0) }
            if requiredMatches.count == rewrite.requiredTerms.count {
                exactScore += 0.08
                matched.insert(.exact)
            } else {
                lexicalScore -= 0.12
            }
        }

        var recency = recencyScore(for: clip, now: now)
        if let timeRange = rewrite.timeRange {
            if timeRange.contains(clip.capturedAt) {
                recency = max(recency, 0.92)
                matched.insert(.recency)
            } else {
                recency *= 0.25
            }
        }

        let snippet = snippet(for: clip, document: document, rewrite: rewrite)
        return SearchCandidate(
            clipID: clip.id,
            lexicalScore: clamp01(lexicalScore),
            semanticScore: 0,
            aliasScore: clamp01(aliasScore),
            taxonomyScore: clamp01(taxonomyScore),
            recencyScore: clamp01(recency),
            exactScore: clamp01(exactScore),
            matchedFields: Array(matched).sorted { $0.label < $1.label },
            matchedSnippet: snippet
        )
    }

    private static func snippet(for clip: ClipItem, document: SearchDocument, rewrite: QueryRewrite) -> String {
        let lookupTerms = rewrite.allTerms.filter { !$0.isEmpty }
        let orderedSources: [(original: String, lookup: String)] = [
            (clip.aiSummary, document.summaryText),
            (clip.excerpt, SemanticSearchToolkit.normalizedLookup(clip.excerpt)),
            (clip.content, document.contentText),
            (clip.readingPayload?.summaryChinese ?? "", SemanticSearchToolkit.normalizedLookup(clip.readingPayload?.summaryChinese ?? "")),
            (clip.readingPayload?.titleChinese ?? "", SemanticSearchToolkit.normalizedLookup(clip.readingPayload?.titleChinese ?? "")),
            (clip.title, SemanticSearchToolkit.normalizedLookup(clip.title))
        ]

        for source in orderedSources where !source.original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let term = lookupTerms.first(where: { source.lookup.contains($0) }),
               let snippet = extractSnippet(from: source.original, term: term) {
                return compactSummary(from: snippet)
            }
        }

        return fallbackSnippet(for: clip)
    }

    private static func extractSnippet(from text: String, term: String) -> String? {
        let normalized = SemanticSearchToolkit.normalizedLookup(text)
        guard let range = normalized.range(of: term) else { return nil }
        let startOffset = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let endOffset = normalized.distance(from: normalized.startIndex, to: range.upperBound)
        let lowerBound = text.index(text.startIndex, offsetBy: max(0, startOffset - 72), limitedBy: text.endIndex) ?? text.startIndex
        let upperBound = text.index(text.startIndex, offsetBy: min(text.count, endOffset + 96), limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lowerBound..<upperBound])
    }

    private static func fallbackSnippet(for clip: ClipItem) -> String {
        compactSummary(from: clip.aiSummary.isEmpty ? clip.excerpt.isEmpty ? clip.title : clip.excerpt : clip.aiSummary)
    }

    private static func recencyScore(for clip: ClipItem, now: Date) -> Double {
        let ageDays = max(0, now.timeIntervalSince(clip.capturedAt) / 86_400)
        return clamp01(exp(-ageDays / 45))
    }

    private static func clamp01(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

public func encodeStringArray(_ values: [String]) -> String {
    let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    let data = (try? JSONEncoder().encode(cleaned)) ?? Data("[]".utf8)
    return String(data: data, encoding: .utf8) ?? "[]"
}

public func decodeStringArray(_ value: String) -> [String] {
    guard let data = value.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
}

public func floorToHour(_ date: Date, calendar: Calendar = .current) -> Date {
    var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    components.minute = 0
    components.second = 0
    return calendar.date(from: components) ?? date
}

public func normalizedDomain(from urlString: String) -> String {
    URL(string: urlString)?.host?.lowercased() ?? ""
}

public func compactSummary(from text: String) -> String {
    let trimmed = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    if trimmed.count <= 220 {
        return trimmed
    }
    let index = trimmed.index(trimmed.startIndex, offsetBy: 220)
    return String(trimmed[..<index]) + "..."
}

public func isLikelyEnglishText(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !CosmoTextClassifier.containsChinese(trimmed) else {
        return false
    }

    let asciiLetters = trimmed.unicodeScalars.filter { scalar in
        (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }.count
    let nonWhitespace = trimmed.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    guard asciiLetters >= 24, nonWhitespace > 0 else {
        return false
    }

    return Double(asciiLetters) / Double(nonWhitespace) >= 0.45
}

public func clipboardDisplayTitle(from text: String, limit: Int = 88) -> String {
    let normalized = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "Clipboard Capture" }
    if normalized.count <= limit {
        return normalized
    }
    let index = normalized.index(normalized.startIndex, offsetBy: limit)
    return String(normalized[..<index]) + "..."
}

public func plainTextParagraphs(from text: String) -> [String] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    return normalized
        .components(separatedBy: "\n\n")
        .map {
            $0
                .replacingOccurrences(of: "\n[ \t]+", with: "\n", options: .regularExpression)
                .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
}
