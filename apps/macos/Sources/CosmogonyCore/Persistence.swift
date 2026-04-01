import Foundation
import GRDB
import Security
import ServiceManagement

struct ExportEnvelope: Codable, Sendable {
    var items: [ClipItem]
    var categoryRules: [CategoryRule]
    var spaces: [Space]
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
        migrator.registerMigration("v2_spaces") { db in
            try db.create(table: "spaces") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("tags_json", .text).notNull().defaults(to: "[]")
                table.column("created_at", .double).notNull()
                table.column("updated_at", .double).notNull()
            }

            try db.alter(table: "clip_items") { table in
                table.add(column: "space_id", .text)
                table.add(column: "space_name", .text).notNull().defaults(to: "")
            }
        }
        migrator.registerMigration("v3_clip_flags") { db in
            try db.alter(table: "clip_items") { table in
                table.add(column: "is_pinned", .boolean).notNull().defaults(to: false)
                table.add(column: "trashed_at", .double)
            }
            try db.execute(
                sql: "UPDATE clip_items SET trashed_at = captured_at WHERE status = ? AND trashed_at IS NULL",
                arguments: [ClipStatus.trashed.rawValue]
            )
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

        let profiles = try fetchProviderProfiles()
        if !profiles.contains(where: { $0.id == "deepseek-local-test" }) {
            let deepSeekProfile = ProviderProfile(
                id: "deepseek-local-test",
                kind: .deepseek,
                displayName: "DeepSeek Local Test",
                apiKeyRef: "deepseek.local.test",
                baseURL: ProviderKind.deepseek.suggestedBaseURL,
                defaultModel: "deepseek-chat",
                embeddingModel: "",
                enabled: true
            )
            try saveProviderProfile(deepSeekProfile)
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

    func fetchSpaces() throws -> [Space] {
        try dbQueue.read { db in
            try Space.fetchAll(db).sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func saveCategoryRule(_ rule: CategoryRule) throws {
        try dbQueue.write { db in
            try rule.save(db)
        }
    }

    func saveSpace(_ space: Space) throws {
        try dbQueue.write { db in
            try space.save(db)
        }
    }

    func deleteCategoryRule(id: String) throws {
        try dbQueue.write { db in
            _ = try CategoryRule.deleteOne(db, key: id)
        }
    }

    func deleteSpace(id: String) throws {
        try dbQueue.write { db in
            _ = try Space.deleteOne(db, key: id)
            try db.execute(sql: "UPDATE clip_items SET space_id = NULL, space_name = '' WHERE space_id = ?", arguments: [id])
        }
    }

    func saveClip(_ clip: ClipItem) throws {
        try dbQueue.write { db in
            try clip.save(db)
        }
    }

    func deleteClip(id: String) throws {
        try dbQueue.write { db in
            _ = try ClipItem.deleteOne(db, key: id)
        }
    }

    func fetchClip(id: String) throws -> ClipItem? {
        try dbQueue.read { db in
            try ClipItem.fetchOne(db, key: id)
        }
    }

    func fetchClip(url: String) throws -> ClipItem? {
        try dbQueue.read { db in
            try ClipItem
                .filter(Column("url") == url)
                .order(Column("captured_at").desc)
                .fetchOne(db)
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
        spaceID: String?,
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
                case .all:
                    clip.status != .trashed
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

            if let spaceID, !spaceID.isEmpty {
                clips = clips.filter { $0.spaceID == spaceID }
            }

            clips = clips.filter { timebox.contains($0.capturedAt) }

            let trimmedQuery = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                return clips.sorted(by: clipSort)
            }

            let scored = clips
                .map { ($0, SearchScorer.score($0, query: trimmedQuery)) }
                .filter { _, score in score > 0 || mode == .embeddingReady }
                .sorted {
                    if $0.1 == $1.1 {
                        return clipSort($0.0, $1.0)
                    }
                    return $0.1 > $1.1
                }

            return scored.map(\.0)
        }
    }

    func cleanupExpiredTrash(retentionDays: Int = 30, now: Date = .now) throws {
        let cutoff = now.addingTimeInterval(TimeInterval(-86_400 * retentionDays))
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM clip_items WHERE status = ? AND trashed_at IS NOT NULL AND trashed_at < ?",
                arguments: [ClipStatus.trashed.rawValue, cutoff.timeIntervalSince1970]
            )
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
        let spaces = try fetchSpaces()
        let payload = ExportEnvelope(items: items, categoryRules: rules, spaces: spaces)
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
                status: mapLegacyStatus(legacy.status),
                trashedAt: mapLegacyStatus(legacy.status) == .trashed ? capturedAt : nil
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

private func clipSort(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
    if lhs.isPinned != rhs.isPinned {
        return lhs.isPinned && !rhs.isPinned
    }
    return lhs.capturedAt > rhs.capturedAt
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
        ),

        // Curated built-in links
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Neurodivergent by Design: Using AI to Honor and Support Learning Differences",
            url: "https://www.intechopen.com/online-first/1230197",
            summary: "IntechOpen 的 AI 与学习差异研究文章，适合归档学术研究与教育科技类内容。",
            category: "学术研究",
            tags: ["research", "ai", "education", "neurodiversity"]
        ),
        SeedClipDefinition(
            bucket: .wechat,
            title: "微信公众号文章",
            url: "https://mp.weixin.qq.com/s/pdZBFWcdxtYea39o-iPLrg",
            summary: "来自微信公众号的中文长文链接，用于归档公众号内容与中文信息流样例。",
            category: "微信公众号",
            tags: ["wechat", "article", "longread", "chinese"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Zolplay Work",
            url: "https://zolplay.com/zh-CN/work",
            summary: "Zolplay 的作品集页面，适合整理工作室案例、产品设计与品牌展示类链接。",
            category: "作品集",
            tags: ["portfolio", "studio", "design", "zolplay"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "Edward Luo on X - Vibe Island",
            url: "https://x.com/imedwardluo/status/2039266737263349870",
            summary: "Edward Luo 分享的 Vibe Island Mac 动态岛应用帖子，适合归档产品想法与 AI 原生应用观察。",
            category: "X 动态",
            tags: ["x", "ai", "mac", "product", "vibe-island"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "ebook-GPT-translator README-zh",
            url: "https://github.com/jesselau76/ebook-GPT-translator/blob/main/README-zh.md",
            summary: "电子书 GPT 翻译工具的中文说明文档，适合收录阅读工具与开源项目资料。",
            category: "GitHub 项目",
            tags: ["github", "ebook", "translation", "gpt", "tool"]
        ),
        SeedClipDefinition(
            bucket: .youtube,
            title: "mymind: Pinterest for Productivity Nerds",
            url: "https://www.youtube.com/watch?v=YwKPw16FzNU",
            summary: "关于 mymind 的 YouTube 视频，适合归档知识管理与效率产品相关视频内容。",
            category: "视频",
            tags: ["youtube", "productivity", "knowledge-management", "mymind"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Bitcoin rainbow chart shows price is now below",
            url: "https://www.reddit.com/r/wallstreetbets/comments/1s6dc58/bitcoin_rainbow_chart_shows_price_is_now_below/",
            summary: "WallStreetBets 里的比特币彩虹图讨论串，适合归档市场情绪与社区讨论样例。",
            category: "Reddit 讨论",
            tags: ["reddit", "bitcoin", "market", "community", "wallstreetbets"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "数字生命卡兹克 on X",
            url: "https://x.com/khazix0918/status/2038828707247485041?s=12",
            summary: "来自数字生命卡兹克的 X 帖子，适合归档短链分享与 AI 社区动态类内容。",
            category: "X 动态",
            tags: ["x", "share", "ai", "community", "khazix"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "WquGuru on X - Claude Code and Codex book thread",
            url: "https://x.com/wquguru/status/2039333332987810103?s=12",
            summary: "WquGuru 分享 Claude Code 与 Codex 相关书单的帖子，适合归档开发工具与学习资料线索。",
            category: "X 动态",
            tags: ["x", "claude-code", "codex", "books", "learning"]
        ),
        SeedClipDefinition(
            bucket: .xPosts,
            title: "宝玉 on X - codex-plugin-cc",
            url: "https://x.com/dotey/status/2038682622180634793?s=12",
            summary: "宝玉转发 OpenAI codex-plugin-cc 相关动态，适合归档 AI 编码插件与工作流更新。",
            category: "X 动态",
            tags: ["x", "openai", "codex", "plugin", "claude-code"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Quick Start - Wiki | EvoMap",
            url: "https://evomap.ai/wiki/01-quick-start",
            summary: "EvoMap 的快速开始文档，适合作为 Agent 地图、知识组织与产品上手资料样例。",
            category: "产品文档",
            tags: ["docs", "agent", "knowledge-map", "quick-start", "evomap"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Juchats - Address user needs using natural language",
            url: "https://celhive.ai/",
            summary: "Celhive 首页，展示以自然语言满足用户需求的 AI 产品方向。",
            category: "AI 工具",
            tags: ["ai", "assistant", "product", "workflow", "celhive"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Step1 - Clone Any Website & Ship Designer-Level Sites With AI",
            url: "https://step1.dev/",
            summary: "Step1 的 AI 建站产品页面，适合归档设计生成与前端生产力工具链接。",
            category: "AI 建站",
            tags: ["ai", "web-builder", "design", "frontend", "step1"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "BenchFlow - High Signal Environments for Agents",
            url: "https://www.benchflow.ai/",
            summary: "BenchFlow 提供面向 Agent 的高信号测试环境，适合收录评测与实验平台资料。",
            category: "Agent 基准",
            tags: ["agent", "benchmark", "evaluation", "testing", "benchflow"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Kindle 图书资源 - 书伴",
            url: "https://bookfere.com/ebook",
            summary: "书伴的 Kindle 图书资源页面，适合归档电子书与阅读资源相关链接。",
            category: "阅读资源",
            tags: ["ebook", "kindle", "reading", "resource", "bookfere"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Agentic AI and the next intelligence explosion",
            url: "https://www.science.org/doi/10.1126/science.aeg1895",
            summary: "Science 上关于 Agentic AI 的文章，适合归档前沿研究与趋势判断类资料。",
            category: "学术研究",
            tags: ["research", "agentic-ai", "science", "paper", "trend"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "gstack",
            url: "https://github.com/garrytan/gstack",
            summary: "Garry Tan 的 Claude Code 配置与工具集合，适合归档 AI 编码工作流项目。",
            category: "GitHub 项目",
            tags: ["github", "claude-code", "workflow", "tools", "gstack"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "sub2api",
            url: "https://github.com/Wei-Shaw/sub2api",
            summary: "Sub2API 开源中转服务项目，适合收录多模型统一接入与 API 中台方案。",
            category: "GitHub 项目",
            tags: ["github", "api", "gateway", "llm", "sub2api"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "BotLearn - Send Your AI Agents to School",
            url: "https://www.botlearn.ai/7-step",
            summary: "BotLearn 的 7-step 页面，适合归档 Agent 训练、教学与任务设计类内容。",
            category: "Agent 学习",
            tags: ["agent", "training", "education", "workflow", "botlearn"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "2026 开源AI书签系统：MindPocket 私有部署 RAG 知识库",
            url: "https://www.ahhhhfs.com/79608/",
            summary: "A姐分享的 MindPocket 文章，适合收录书签系统、RAG 与私有知识库相关资料。",
            category: "书签系统",
            tags: ["bookmark", "rag", "knowledge-base", "self-hosted", "mindpocket"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "BotCord - Discord for Bots",
            url: "https://www.botcord.chat/",
            summary: "BotCord 的产品主页，适合归档 Bot 协作与社区基础设施类项目。",
            category: "Bot 社区",
            tags: ["bot", "community", "chat", "infrastructure", "botcord"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "MCP is Dead; Long Live MCP!",
            url: "https://chrlschn.dev/blog/2026/03/mcp-is-dead-long-live-mcp/",
            summary: "关于 MCP 未来形态的博客文章，适合归档协议、Agent 架构与技术观点讨论。",
            category: "技术博客",
            tags: ["mcp", "agent", "protocol", "blog", "architecture"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "I was backend lead at Manus. After building agents for 2 years, I stopped using function calling entirely.",
            url: "https://www.reddit.com/r/LocalLLaMA/comments/1rrisqn/i_was_backend_lead_at_manus_after_building_agents/",
            summary: "LocalLLaMA 上关于 Agent 工程实践的讨论串，适合归档经验分享与架构观点。",
            category: "Reddit 讨论",
            tags: ["reddit", "agent", "manus", "function-calling", "engineering"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Whitespace Control - Templater",
            url: "https://silentvoid13.github.io/Templater/commands/whitespace-control.html",
            summary: "Templater 的空白字符控制文档页，适合收录 Obsidian 插件文档与模板技巧。",
            category: "文档",
            tags: ["docs", "obsidian", "templater", "plugin", "markdown"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Beacon - Linear Client Portal for Studios",
            url: "https://beacon.zolplay.co/",
            summary: "Beacon 的产品主页，适合归档工作室客户门户、项目协同与 Linear 周边产品。",
            category: "产品",
            tags: ["product", "linear", "client-portal", "studio", "beacon"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "UDEMY FREE | Coursevania",
            url: "https://t.me/Udemy4/78095",
            summary: "Telegram 中的课程资源消息链接，用于归档 Telegram 社区内容入口。",
            category: "Telegram",
            tags: ["telegram", "course", "community", "resource", "udemy4"]
        ),
        SeedClipDefinition(
            bucket: .otherWeb,
            title: "Telegram Web - @piracy6",
            url: "https://web.telegram.org/k/#@piracy6",
            summary: "Telegram Web 中的频道入口链接，可作为外部社区链接的归档样例。",
            category: "Telegram",
            tags: ["telegram", "channel", "community", "web"]
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
