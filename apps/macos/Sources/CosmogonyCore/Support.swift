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
    case embeddingReady = "embedding_ready"

    public var label: String {
        switch self {
        case .lexicalFallback: "Local lexical/taxonomy"
        case .embeddingReady: "Embedding-ready"
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

    public static let captureCurrentPageDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_S), command: true, shift: true, option: false, control: false)
    public static let captureClipboardDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_V), command: true, shift: true, option: false, control: false)

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
    case captureCurrentPage
    case captureClipboard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .captureCurrentPage: "剪藏当前网页"
        case .captureClipboard: "剪藏剪贴板"
        }
    }
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public var captureCurrentPage: KeyCombination = .captureCurrentPageDefault
    public var captureClipboard: KeyCombination = .captureClipboardDefault

    public init(
        captureCurrentPage: KeyCombination = .captureCurrentPageDefault,
        captureClipboard: KeyCombination = .captureClipboardDefault
    ) {
        self.captureCurrentPage = captureCurrentPage
        self.captureClipboard = captureClipboard
    }

    public func conflictMessage() -> String? {
        guard captureCurrentPage == captureClipboard else { return nil }
        return "两个全局快捷键不能相同。"
    }
}

public struct CaptureSettings: Codable, Equatable, Sendable {
    public var enrichPublicPages = true
    public var preferBridgeRichCapture = true
    public var maxStoredCharacters = 12_000

    public init(enrichPublicPages: Bool = true, preferBridgeRichCapture: Bool = true, maxStoredCharacters: Int = 12_000) {
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
    public var note: String
    public var status: ClipStatus
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
        note: String,
        status: ClipStatus
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
        self.note = note
        self.status = status
        self.searchText = ClipItem.composeSearchText(title: title, domain: domain, excerpt: excerpt, content: content, category: category, tags: tags, note: note)
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
        note = row["note"] ?? ""
        status = ClipStatus(rawValue: row["status"] ?? "") ?? .inbox
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
        container["note"] = note
        container["status"] = status.rawValue
        container["search_text"] = searchText
    }

    public mutating func refreshSearchText() {
        searchText = ClipItem.composeSearchText(
            title: title,
            domain: domain,
            excerpt: excerpt,
            content: content,
            category: category,
            tags: tags,
            note: note
        )
    }

    public static func composeSearchText(
        title: String,
        domain: String,
        excerpt: String,
        content: String,
        category: String,
        tags: [String],
        note: String
    ) -> String {
        [title, domain, excerpt, content, category, tags.joined(separator: " "), note]
            .joined(separator: " ")
            .lowercased()
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
    public static func mode(settings: AppSettings, profiles: [ProviderProfile]) -> SearchMode {
        guard
            let id = settings.defaultEmbeddingProfileID,
            let profile = profiles.first(where: { $0.id == id }),
            profile.supportsEmbeddings
        else {
            return .lexicalFallback
        }
        return .embeddingReady
    }

    public static func score(_ clip: ClipItem, query: String) -> Int {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return 0 }

        var total = 0
        let haystack = clip.searchText

        if clip.title.lowercased().contains(normalized) {
            total += 80
        }
        if clip.domain.lowercased().contains(normalized) {
            total += 50
        }
        if clip.category.lowercased().contains(normalized) {
            total += 40
        }
        if clip.tags.contains(where: { $0.lowercased().contains(normalized) }) {
            total += 35
        }

        for token in normalized.split(separator: " ").map(String.init) where !token.isEmpty {
            if haystack.contains(token) {
                total += 10
            }
        }

        return total
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
