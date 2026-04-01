import Foundation
import GRDB
import Security
import ServiceManagement

struct ExportEnvelope: Codable, Sendable {
    var items: [ClipItem]
    var categoryRules: [CategoryRule]
}

private struct SettingsRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_settings"

    var key: String
    var valueJSON: String

    init(key: String, valueJSON: String) {
        self.key = key
        self.valueJSON = valueJSON
    }

    init(row: Row) {
        key = row["key"]
        valueJSON = row["value_json"] ?? "{}"
    }

    func encode(to container: inout PersistenceContainer) {
        container["key"] = key
        container["value_json"] = valueJSON
    }
}

private struct LegacyBookmarkImport: Decodable {
    var id: String?
    var url: String?
    var canonicalUrl: String?
    var title: String?
    var domain: String?
    var createdAt: String?
    var updatedAt: String?
    var lastSavedAt: String?
    var aiSummary: String?
    var category: String?
    var tags: [String]?
    var userNote: String?
    var status: String?
    var searchText: String?
}

private struct LegacyCategoryRuleImport: Decodable {
    var canonical: String?
    var aliases: [String]?
}

private struct LegacyExportEnvelope: Decodable {
    var items: [LegacyBookmarkImport]?
    var categoryRules: [LegacyCategoryRuleImport]?
}

final class AppDatabase {
    let dbQueue: DatabaseQueue
    let databaseURL: URL

    init() throws {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appURL = supportURL.appendingPathComponent("Cosmogony", isDirectory: true)
        try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        databaseURL = appURL.appendingPathComponent("cosmogony.sqlite")
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
        try ensureSeedData()
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "clip_items") { table in
                table.column("id", .text).primaryKey()
                table.column("source_type", .text).notNull()
                table.column("url", .text).notNull()
                table.column("title", .text).notNull()
                table.column("domain", .text).notNull()
                table.column("platform_bucket", .text).notNull()
                table.column("captured_at", .double).notNull()
                table.column("captured_hour_bucket", .double).notNull()
                table.column("excerpt", .text).notNull().defaults(to: "")
                table.column("content", .text).notNull().defaults(to: "")
                table.column("ai_summary", .text).notNull().defaults(to: "")
                table.column("category", .text).notNull().defaults(to: "")
                table.column("tags_json", .text).notNull().defaults(to: "[]")
                table.column("note", .text).notNull().defaults(to: "")
                table.column("status", .text).notNull()
                table.column("search_text", .text).notNull().defaults(to: "")
            }

            try db.create(index: "clip_items_scope_idx", on: "clip_items", columns: ["status", "captured_at"])
            try db.create(index: "clip_items_platform_idx", on: "clip_items", columns: ["platform_bucket", "captured_hour_bucket"])

            try db.create(table: "provider_profiles") { table in
                table.column("id", .text).primaryKey()
                table.column("kind", .text).notNull()
                table.column("display_name", .text).notNull()
                table.column("api_key_ref", .text).notNull()
                table.column("base_url", .text).notNull().defaults(to: "")
                table.column("default_model", .text).notNull()
                table.column("embedding_model", .text).notNull().defaults(to: "")
                table.column("enabled", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "category_rules") { table in
                table.column("id", .text).primaryKey()
                table.column("canonical", .text).notNull()
                table.column("aliases_json", .text).notNull().defaults(to: "[]")
                table.column("updated_at", .double).notNull()
            }

            try db.create(table: "app_settings") { table in
                table.column("key", .text).primaryKey()
                table.column("value_json", .text).notNull()
            }
        }
        return migrator
    }

    private func ensureSeedData() throws {
        let settings = try fetchSettings()
        if try fetchProviderProfiles().isEmpty {
            let defaultProfile = ProviderProfile(
                kind: .openAI,
                displayName: "OpenAI Primary",
                baseURL: ProviderKind.openAI.suggestedBaseURL,
                defaultModel: "gpt-4.1-mini",
                embeddingModel: "text-embedding-3-small"
            )
            try saveProviderProfile(defaultProfile)

            var nextSettings = settings
            nextSettings.defaultReasoningProfileID = defaultProfile.id
            nextSettings.defaultEmbeddingProfileID = defaultProfile.id
            try saveSettings(nextSettings)
        }

        try ensureSeedClips()
    }

    private func ensureSeedClips() throws {
        let existingURLs = Set(try fetchAllClips().map(\.url))
        let missingSeeds = SeedLibrary.defaultClips().filter { !existingURLs.contains($0.url) }
        guard !missingSeeds.isEmpty else { return }

        try dbQueue.write { db in
            for clip in missingSeeds {
                try clip.save(db)
            }
        }
    }

    func fetchSettings() throws -> AppSettings {
        try dbQueue.read { db in
            if let row = try SettingsRow.fetchOne(db, key: "current"),
               let data = row.valueJSON.data(using: .utf8),
               let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return settings
            }
            return AppSettings()
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        let json = String(decoding: data, as: UTF8.self)
        try dbQueue.write { db in
            try SettingsRow(key: "current", valueJSON: json).save(db)
        }
    }

    func fetchProviderProfiles() throws -> [ProviderProfile] {
        try dbQueue.read { db in
            try ProviderProfile.fetchAll(db).sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    func saveProviderProfile(_ profile: ProviderProfile) throws {
        try dbQueue.write { db in
            try profile.save(db)
        }
    }

    func deleteProviderProfile(id: String) throws {
        try dbQueue.write { db in
            _ = try ProviderProfile.deleteOne(db, key: id)
        }
    }

    func fetchCategoryRules() throws -> [CategoryRule] {
        try dbQueue.read { db in
            try CategoryRule.fetchAll(db).sorted { $0.canonical.localizedCaseInsensitiveCompare($1.canonical) == .orderedAscending }
        }
    }

    func saveCategoryRule(_ rule: CategoryRule) throws {
        try dbQueue.write { db in
            try rule.save(db)
        }
    }

    func deleteCategoryRule(id: String) throws {
        try dbQueue.write { db in
            _ = try CategoryRule.deleteOne(db, key: id)
        }
    }

    func saveClip(_ clip: ClipItem) throws {
        try dbQueue.write { db in
            try clip.save(db)
        }
    }

    func fetchClip(id: String) throws -> ClipItem? {
        try dbQueue.read { db in
            try ClipItem.fetchOne(db, key: id)
        }
    }

    func fetchAllClips() throws -> [ClipItem] {
        try dbQueue.read { db in
            try ClipItem.fetchAll(db)
        }
    }

    func fetchClips(
        scope: ClipScope,
        platformFilter: PlatformFilter,
        timebox: TimeboxFilter,
        search: String,
        settings: AppSettings,
        profiles: [ProviderProfile]
    ) throws -> [ClipItem] {
        let mode = SearchScorer.mode(settings: settings, profiles: profiles)
        return try dbQueue.read { db in
            var clips = try ClipItem.fetchAll(db)
            clips = clips.filter { clip in
                switch scope {
                case .inbox:
                    clip.status == .inbox
                case .library:
                    clip.status == .library || clip.status == .failed
                case .trash:
                    clip.status == .trashed
                }
            }

            clips = clips.filter { clip in
                switch platformFilter {
                case .all:
                    true
                case let .bucket(bucket):
                    clip.platformBucket == bucket
                }
            }

            clips = clips.filter { timebox.contains($0.capturedAt) }

            let trimmedQuery = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                return clips.sorted { $0.capturedAt > $1.capturedAt }
            }

            let scored = clips
                .map { ($0, SearchScorer.score($0, query: trimmedQuery)) }
                .filter { _, score in score > 0 || mode == .embeddingReady }
                .sorted {
                    if $0.1 == $1.1 {
                        return $0.0.capturedAt > $1.0.capturedAt
                    }
                    return $0.1 > $1.1
                }

            return scored.map(\.0)
        }
    }

    func fetchStats(timebox: TimeboxFilter) throws -> ClipStats {
        let clips = try fetchAllClips().filter { timebox.contains($0.capturedAt) }
        var bucketCounts: [PlatformBucket: Int] = [:]
        for clip in clips {
            bucketCounts[clip.platformBucket, default: 0] += 1
        }

        return ClipStats(
            totalCount: clips.count,
            inboxCount: clips.filter { $0.status == .inbox }.count,
            libraryCount: clips.filter { $0.status == .library }.count,
            failedCount: clips.filter { $0.status == .failed }.count,
            trashCount: clips.filter { $0.status == .trashed }.count,
            bucketCounts: bucketCounts
        )
    }

    func exportLibrary() throws -> Data {
        let items = try dbQueue.read { db in
            try ClipItem.fetchAll(db)
        }
        let rules = try fetchCategoryRules()
        let payload = ExportEnvelope(items: items, categoryRules: rules)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func importLegacyExport(from data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: LegacyExportEnvelope
        if let value = try? decoder.decode(LegacyExportEnvelope.self, from: data) {
            envelope = value
        } else {
            let items = try decoder.decode([LegacyBookmarkImport].self, from: data)
            envelope = LegacyExportEnvelope(items: items, categoryRules: [])
        }

        let categories = (envelope.categoryRules ?? []).compactMap { incoming -> CategoryRule? in
            guard let canonical = incoming.canonical?.trimmingCharacters(in: .whitespacesAndNewlines), !canonical.isEmpty else {
                return nil
            }
            return CategoryRule(canonical: canonical, aliases: incoming.aliases ?? [])
        }

        try dbQueue.write { db in
            for rule in categories {
                try rule.save(db)
            }
        }

        var imported = 0
        for legacy in envelope.items ?? [] {
            let rawURL = (legacy.canonicalUrl ?? legacy.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawURL.isEmpty else { continue }

            let capturedAt = parseDate(legacy.lastSavedAt) ?? parseDate(legacy.updatedAt) ?? parseDate(legacy.createdAt) ?? .now
            var clip = ClipItem(
                sourceType: .webPage,
                url: rawURL,
                title: (legacy.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? legacy.title! : rawURL),
                domain: (legacy.domain?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? legacy.domain! : normalizedDomain(from: rawURL)),
                platformBucket: PlatformClassifier.bucket(for: rawURL),
                capturedAt: capturedAt,
                capturedHourBucket: floorToHour(capturedAt),
                excerpt: compactSummary(from: legacy.searchText ?? legacy.aiSummary ?? ""),
                content: legacy.searchText ?? "",
                aiSummary: legacy.aiSummary ?? "",
                category: legacy.category ?? "",
                tags: legacy.tags ?? [],
                note: legacy.userNote ?? "",
                status: mapLegacyStatus(legacy.status)
            )
            clip.refreshSearchText()
            try saveClip(clip)
            imported += 1
        }

        return imported
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func mapLegacyStatus(_ value: String?) -> ClipStatus {
        switch value?.lowercased() {
        case "trashed":
            .trashed
        case "classified":
            .library
        case "error":
            .failed
        default:
            .inbox
        }
    }
}

final class KeychainStore {
    func loadString(service: String, account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func saveString(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
            }
        } else {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(insertStatus))
            }
        }
    }

    func deleteString(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

private enum SeedLibrary {
    static func defaultClips(now: Date = .now) -> [ClipItem] {
        definitions.enumerated().map { index, definition in
            var clip = ClipItem(
                sourceType: .webPage,
                url: definition.url,
                title: definition.title,
                domain: normalizedDomain(from: definition.url),
                platformBucket: definition.bucket,
                capturedAt: now.addingTimeInterval(TimeInterval(-((index + 1) * 5400))),
                capturedHourBucket: floorToHour(now.addingTimeInterval(TimeInterval(-((index + 1) * 5400)))),
                excerpt: definition.summary,
                content: definition.summary,
                aiSummary: definition.summary,
                category: definition.category,
                tags: definition.tags,
                note: "",
                status: .library
            )
            clip.refreshSearchText()
            return clip
        }
    }

    private static let definitions: [SeedClipDefinition] = [
        SeedClipDefinition(
            bucket: .xPosts,
            title: "OpenAI on X",
            url: "https://x.com/OpenAI",
            summary: "OpenAI 官方 X 页面，适合验证 X 平台分类、链接展示与搜索命中。",
            category: "AI updates",
            tags: ["x", "openai", "official"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "TwitterDev on X",
            url: "https://x.com/TwitterDev",
            summary: "TwitterDev 的公开页面，用来测试开发者资讯类内容的收录效果。",
            category: "Developer news",
            tags: ["x", "developer", "api"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "GitHub on X",
            url: "https://x.com/github",
            summary: "GitHub 官方 X 页面，补充代码与产品更新场景的示例。",
            category: "Product updates",
            tags: ["x", "github", "product"]
        ),
        SeedClipDefinition(
            bucket: .rednote,
            title: "小红书首页",
            url: "https://www.xiaohongshu.com/",
            summary: "小红书官网首页，用作生活方式与灵感流内容的基础样例。",
            category: "Lifestyle",
            tags: ["xiaohongshu", "home", "discover"]
        ),
        SeedClipDefinition(
            bucket: .rednote,
            title: "小红书 Explore",
            url: "https://www.xiaohongshu.com/explore",
            summary: "小红书 Explore 页面，适合验证图文灵感内容的分类模块展示。",
            category: "Inspiration",
            tags: ["xiaohongshu", "explore", "inspiration"]
        ),
        SeedClipDefinition(
            bucket: .rednote,
            title: "关于小红书",
            url: "https://www.xiaohongshu.com/about",
            summary: "品牌与平台介绍页，作为更稳定的公开页面种子数据。",
            category: "Brand story",
            tags: ["xiaohongshu", "about", "brand"]
        ),
        SeedClipDefinition(
            bucket: .wechat,
            title: "微信公众平台",
            url: "https://mp.weixin.qq.com/",
            summary: "微信公众号平台首页，用作公众号来源的标准公开入口。",
            category: "WeChat",
            tags: ["wechat", "official-account", "platform"]
        ),
        SeedClipDefinition(
            bucket: .wechat,
            title: "公众号后台首页",
            url: "https://mp.weixin.qq.com/cgi-bin/home?t=home/index",
            summary: "公众号后台首页地址，可用于验证 mp.weixin.qq.com 域名分类与检索。",
            category: "Creator tools",
            tags: ["wechat", "dashboard", "creator"]
        ),
        SeedClipDefinition(
            bucket: .wechat,
            title: "微信公众号示例文章",
            url: "https://mp.weixin.qq.com/s?__biz=MzA3NjQzNTQzMA==&mid=2651731488&idx=1&sn=1",
            summary: "真实可访问的公众号文章地址，用于验证长文内容卡片与搜索索引。",
            category: "Long-form article",
            tags: ["wechat", "article", "longread"]
        ),
        SeedClipDefinition(
            bucket: .douyin,
            title: "抖音首页",
            url: "https://www.douyin.com/",
            summary: "抖音官方首页，用于短视频平台的基础模块示例。",
            category: "Short video",
            tags: ["douyin", "home", "video"]
        ),
        SeedClipDefinition(
            bucket: .douyin,
            title: "抖音发现页",
            url: "https://www.douyin.com/discover",
            summary: "抖音 Discover 页面，适合演示探索流与热点入口类页面。",
            category: "Discovery",
            tags: ["douyin", "discover", "trending"]
        ),
        SeedClipDefinition(
            bucket: .douyin,
            title: "抖音热点",
            url: "https://www.douyin.com/hot",
            summary: "抖音热点页，用来补齐短视频趋势内容的真实样例。",
            category: "Hot topics",
            tags: ["douyin", "hot", "trend"]
        ),
        SeedClipDefinition(
            bucket: .youtube,
            title: "OpenAI on YouTube",
            url: "https://www.youtube.com/@OpenAI",
            summary: "OpenAI 官方 YouTube 频道，代表知识型视频内容的收录场景。",
            category: "AI video",
            tags: ["youtube", "openai", "channel"]
        ),
        SeedClipDefinition(
            bucket: .youtube,
            title: "Google Developers on YouTube",
            url: "https://www.youtube.com/@GoogleDevelopers",
            summary: "Google Developers 官方频道，适合验证开发者视频搜索与分类效果。",
            category: "Developer video",
            tags: ["youtube", "google", "developer"]
        ),
        SeedClipDefinition(
            bucket: .youtube,
            title: "TED on YouTube",
            url: "https://www.youtube.com/@TED",
            summary: "TED 官方频道，补充演讲与知识内容的公开视频样例。",
            category: "Talks",
            tags: ["youtube", "ted", "talks"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "OpenAI",
            url: "https://openai.com/",
            summary: "开放网页样例之一，用于验证非社交平台内容的通用收录能力。",
            category: "AI website",
            tags: ["web", "openai", "ai"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Apple Developer",
            url: "https://developer.apple.com/",
            summary: "Apple Developer 官网，用作产品与文档类网页的公开样例。",
            category: "Documentation",
            tags: ["web", "apple", "developer"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Wikipedia",
            url: "https://www.wikipedia.org/",
            summary: "Wikipedia 首页，补充知识型、目录型网页的代表样例。",
            category: "Knowledge",
            tags: ["web", "wikipedia", "reference"]
        )
    ]
}

private struct SeedClipDefinition {
    let bucket: PlatformBucket
    let title: String
    let url: String
    let summary: String
    let category: String
    let tags: [String]
}
