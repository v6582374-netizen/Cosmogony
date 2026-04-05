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

final class AppDatabase: @unchecked Sendable {
    let dbQueue: DatabaseQueue
    let databaseURL: URL

    convenience init() throws {
        try self.init(inMemory: false)
    }

    init(inMemory: Bool) throws {
        if inMemory {
            databaseURL = URL(fileURLWithPath: "/dev/null")
            dbQueue = try DatabaseQueue()
            try migrator.migrate(dbQueue)
            try ensureSeedData()
            return
        }

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
        migrator.registerMigration("v4_ai_search_chunks") { db in
            try db.create(table: "clip_search_chunks") { table in
                table.column("id", .text).primaryKey()
                table.column("clip_id", .text).notNull()
                table.column("chunk_index", .integer).notNull()
                table.column("chunk_text", .text).notNull().defaults(to: "")
                table.column("embedding_json", .text).notNull().defaults(to: "[]")
                table.column("content_hash", .text).notNull().defaults(to: "")
                table.column("profile_id", .text).notNull()
                table.column("model_id", .text).notNull().defaults(to: "")
                table.column("updated_at", .double).notNull()
            }
            try db.create(index: "clip_search_chunks_lookup_idx", on: "clip_search_chunks", columns: ["profile_id", "model_id", "clip_id", "chunk_index"])
            try db.create(index: "clip_search_chunks_clip_idx", on: "clip_search_chunks", columns: ["clip_id"])
        }
        migrator.registerMigration("v5_clip_reading_payload") { db in
            try db.alter(table: "clip_items") { table in
                table.add(column: "reading_payload_json", .text).notNull().defaults(to: "")
            }
        }
        migrator.registerMigration("v6_search_alias_rules") { db in
            try db.create(table: "search_alias_rules") { table in
                table.column("id", .text).primaryKey()
                table.column("canonical", .text).notNull()
                table.column("entity_type", .text).notNull()
                table.column("aliases_json", .text).notNull().defaults(to: "[]")
                table.column("is_system", .boolean).notNull().defaults(to: false)
                table.column("updated_at", .double).notNull()
            }
            try db.create(index: "search_alias_rules_canonical_idx", on: "search_alias_rules", columns: ["canonical", "entity_type"])
        }
        migrator.registerMigration("v7_todo_items") { db in
            try db.create(table: "todo_items") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("created_at", .double).notNull()
                table.column("updated_at", .double).notNull()
                table.column("completed_at", .double)
                table.column("visual_seed", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "todo_items_active_idx", on: "todo_items", columns: ["completed_at", "updated_at"])
        }
        migrator.registerMigration("v8_prompt_library_items") { db in
            try db.create(table: "prompt_library_items") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("content", .text).notNull().defaults(to: "")
                table.column("source_label", .text).notNull().defaults(to: "")
                table.column("source_url", .text).notNull().defaults(to: "")
                table.column("created_at", .double).notNull()
                table.column("updated_at", .double).notNull()
                table.column("is_system", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "prompt_library_items_updated_idx", on: "prompt_library_items", columns: ["updated_at"])
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

        try ensureSeedSearchAliases()
        try ensureSeedClips()
        try ensureSeedPromptLibraryItems()
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

    private func ensureSeedSearchAliases() throws {
        let existing = try fetchSearchAliasRules()
        let existingCanonicals = Set(existing.map { "\(SemanticSearchToolkit.normalizedLookup($0.canonical))|\($0.entityType.rawValue)" })
        let missing = SearchAliasRule.systemDefaults().filter { rule in
            !existingCanonicals.contains("\(SemanticSearchToolkit.normalizedLookup(rule.canonical))|\(rule.entityType.rawValue)")
        }
        guard !missing.isEmpty else { return }

        try dbQueue.write { db in
            for rule in missing {
                try rule.save(db)
            }
        }
    }

    private func ensureSeedPromptLibraryItems() throws {
        let existingIDs = Set(try fetchPromptLibraryItems().map(\.id))
        let missing = SeedLibrary.defaultPromptLibraryItems().filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return }

        try dbQueue.write { db in
            for item in missing {
                try item.save(db)
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

    func fetchSearchAliasRules() throws -> [SearchAliasRule] {
        try dbQueue.read { db in
            try SearchAliasRule
                .order(Column("is_system").desc, Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    func upsertSearchAlias(canonical: String, entityType: SearchAliasEntityType, alias: String, isSystem: Bool = false) throws {
        let normalizedCanonical = SemanticSearchToolkit.normalizedLookup(canonical)
        let normalizedAlias = SemanticSearchToolkit.normalizedLookup(alias)
        guard !normalizedCanonical.isEmpty, !normalizedAlias.isEmpty else { return }

        try dbQueue.write { db in
            if var existing = try SearchAliasRule
                .filter(Column("canonical") == normalizedCanonical)
                .filter(Column("entity_type") == entityType.rawValue)
                .fetchOne(db)
            {
                var aliases = existing.aliases.map(SemanticSearchToolkit.normalizedLookup).filter { !$0.isEmpty }
                if !aliases.contains(normalizedAlias) {
                    aliases.append(normalizedAlias)
                    existing.aliases = aliases
                    existing.updatedAt = .now
                    existing.isSystem = existing.isSystem && isSystem
                    try existing.save(db)
                }
                return
            }

            try SearchAliasRule(
                canonical: normalizedCanonical,
                entityType: entityType,
                aliases: [normalizedAlias],
                isSystem: isSystem
            ).save(db)
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

    func fetchPendingTodoItems() throws -> [TodoItem] {
        try dbQueue.read { db in
            try TodoItem
                .filter(Column("completed_at") == nil)
                .order(Column("updated_at").desc, Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func fetchTodoItem(id: String) throws -> TodoItem? {
        try dbQueue.read { db in
            try TodoItem.fetchOne(db, key: id)
        }
    }

    func fetchPromptLibraryItems() throws -> [PromptLibraryItem] {
        try dbQueue.read { db in
            try PromptLibraryItem
                .order(Column("is_system").desc, Column("updated_at").desc, Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func fetchPromptLibraryItem(id: String) throws -> PromptLibraryItem? {
        try dbQueue.read { db in
            try PromptLibraryItem.fetchOne(db, key: id)
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

    func saveTodoItem(_ item: TodoItem) throws {
        try dbQueue.write { db in
            try item.save(db)
        }
    }

    func savePromptLibraryItem(_ item: PromptLibraryItem) throws {
        try dbQueue.write { db in
            try item.save(db)
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
            try db.execute(sql: "DELETE FROM clip_search_chunks WHERE clip_id = ?", arguments: [id])
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

    func fetchNonTrashClips() throws -> [ClipItem] {
        try dbQueue.read { db in
            try ClipItem
                .filter(Column("status") != ClipStatus.trashed.rawValue)
                .fetchAll(db)
                .sorted(by: clipSort)
        }
    }

    func fetchSearchChunks(clipID: String, profileID: String, modelID: String) throws -> [ClipSearchChunk] {
        try dbQueue.read { db in
            try ClipSearchChunk
                .filter(Column("clip_id") == clipID)
                .filter(Column("profile_id") == profileID)
                .filter(Column("model_id") == modelID)
                .order(Column("chunk_index").asc)
                .fetchAll(db)
        }
    }

    func fetchSearchChunks(profileID: String, modelID: String) throws -> [ClipSearchChunk] {
        try dbQueue.read { db in
            try ClipSearchChunk
                .filter(Column("profile_id") == profileID)
                .filter(Column("model_id") == modelID)
                .order(Column("clip_id").asc, Column("chunk_index").asc)
                .fetchAll(db)
        }
    }

    func fetchSearchChunks(clipIDs: [String], profileID: String, modelID: String) throws -> [ClipSearchChunk] {
        guard !clipIDs.isEmpty else { return [] }
        return try dbQueue.read { db in
            try ClipSearchChunk
                .filter(clipIDs.contains(Column("clip_id")))
                .filter(Column("profile_id") == profileID)
                .filter(Column("model_id") == modelID)
                .order(Column("clip_id").asc, Column("chunk_index").asc)
                .fetchAll(db)
        }
    }

    func replaceSearchChunks(_ chunks: [ClipSearchChunk], clipID: String, profileID: String, modelID: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM clip_search_chunks WHERE clip_id = ? AND profile_id = ? AND model_id = ?",
                arguments: [clipID, profileID, modelID]
            )
            for chunk in chunks {
                try chunk.save(db)
            }
        }
    }

    func deleteSearchChunks(clipID: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM clip_search_chunks WHERE clip_id = ?", arguments: [clipID])
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
                .filter { _, score in score > 0 }
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
            try db.execute(sql: "DELETE FROM clip_search_chunks WHERE clip_id NOT IN (SELECT id FROM clip_items)")
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

func clipSort(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
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

    static func defaultPromptLibraryItems(now: Date = .now) -> [PromptLibraryItem] {
        promptDefinitions.enumerated().map { index, definition in
            let timestamp = now.addingTimeInterval(TimeInterval(-index * 900))
            return PromptLibraryItem(
                id: definition.id,
                title: definition.title,
                content: definition.content,
                sourceLabel: definition.sourceLabel,
                sourceURL: definition.sourceURL,
                createdAt: timestamp,
                updatedAt: timestamp,
                isSystem: true
            )
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

    private static let promptDefinitions: [SeedPromptDefinition] = [
        SeedPromptDefinition(
            id: "system-prompt-polish-translator",
            title: "英文润色翻译师",
            content: """
You are an English translator, copy editor, and style improver.

When I write in any language:
1. Detect the original language.
2. Translate the meaning into natural English.
3. Improve the wording so it sounds clear, elegant, and confident.
4. Preserve the original intent, tone, and nuance.

Rules:
- Output only the improved English version.
- Do not explain what you changed.
- Do not add notes, bullets, or commentary unless I explicitly ask.
- If the input is already English, rewrite it into stronger, cleaner English instead of translating it.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-linux-terminal",
            title: "Linux 终端模拟器",
            content: """
Act as a Linux terminal.

I will type shell commands, and you should reply only with the exact terminal output those commands would produce.

Rules:
- Reply with terminal output only.
- Put the output inside a single code block.
- Do not explain commands.
- Do not execute anything unless I explicitly type a command.
- If I need to speak to you outside the terminal session, I will wrap that text in curly braces like {this}.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-js-console",
            title: "JavaScript 控制台",
            content: """
Act as a JavaScript console.

I will send JavaScript statements, and you should reply only with the exact console output.

Rules:
- Return only the output inside one code block.
- Do not add explanations.
- Do not describe the code.
- If I send plain language inside curly braces, treat it as meta-instructions instead of JavaScript input.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-travel-guide",
            title: "旅行路线顾问",
            content: """
Act as a travel guide.

When I give you a location, travel style, or trip goal:
- Recommend places worth visiting nearby.
- Explain briefly why each place fits.
- Suggest a practical visiting order.
- Mention useful local details such as timing, atmosphere, and who the place suits best.

If I specify a category like museums, cafes, bookstores, or architecture, keep the recommendations tightly focused on that category.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-writing-tutor",
            title: "论文写作教练",
            content: """
Act as an AI writing tutor.

Your job is to help improve academic or professional writing.

For every draft I send:
- Diagnose the biggest clarity, structure, and argument issues.
- Rewrite weak passages when useful.
- Suggest stronger wording, transitions, and paragraph logic.
- Preserve my meaning instead of changing my thesis.
- Prioritize concrete edits over vague advice.

If the text is long, start with the top issues first.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-ux-rework",
            title: "UX 体验改造师",
            content: """
Act as a senior UX/UI developer.

I will describe a product, interface, or workflow. Your task is to improve the user experience with practical and creative recommendations.

Always cover:
- the core user goal
- the friction points
- better navigation or information hierarchy
- interaction improvements
- visual or layout refinements
- what to prototype or test next

Favor sharp, implementation-minded feedback over generic design theory.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-web-redesign",
            title: "网站改版顾问",
            content: """
Act as a web design consultant.

When I describe a website or business goal, propose a redesign direction that improves both user experience and business outcomes.

Include:
- the strongest design direction
- better structure and navigation
- key sections the site should contain
- content hierarchy
- conversion opportunities
- visual language recommendations
- technical or implementation considerations if relevant
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-code-review",
            title: "代码审阅助手",
            content: """
Act as an experienced code reviewer for the language and framework I provide.

When I share code:
- identify bugs, edge cases, and behavioral risks first
- point out confusing logic or maintainability issues
- suggest safer or cleaner alternatives
- explain the reasoning behind important findings
- keep feedback concrete and engineering-focused

Do not waste time on praise-only commentary. Prioritize the issues that would matter most in production.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-prd-manager",
            title: "PRD 起草经理",
            content: """
Act as a product manager helping me draft a PRD.

When I give you a feature or product idea, structure the response with:
- Subject
- Introduction
- Problem Statement
- Goals and Objectives
- User Stories
- Technical Requirements
- Benefits
- KPIs
- Risks
- Conclusion

Keep the document clear, specific, and decision-oriented.
""",
            sourceLabel: "prompts.chat (CC0)",
            sourceURL: "https://raw.githubusercontent.com/f/prompts.chat/main/prompts.csv"
        ),
        SeedPromptDefinition(
            id: "system-prompt-text-summarizer",
            title: "文本摘要器",
            content: """
Act as a text summarizer.

When I provide text, distill it into a concise but information-dense summary.

Rules:
- lead with the core thesis
- preserve the most important arguments, decisions, or facts
- remove redundancy
- if helpful, end with a short bullet list of key takeaways
- adapt the compression level to the material: dense docs should stay precise, narrative writing should stay readable
""",
            sourceLabel: "OpenAI best practices inspired",
            sourceURL: "https://help.openai.com/en/articles/6654000-best-practices-for-prompt-engineering-with-the-openai-api%5E.pdf"
        ),
        SeedPromptDefinition(
            id: "system-prompt-info-extractor",
            title: "信息提取器",
            content: """
Extract structured information from the text I provide.

Before answering:
- infer the most useful schema from my request
- normalize inconsistent wording
- keep only information grounded in the source text

Output requirements:
- use clean sections or JSON if I ask for structured output
- mark uncertainty clearly
- never invent missing fields
- if the text is ambiguous, offer the best grounded interpretation and highlight the ambiguity
""",
            sourceLabel: "OpenAI best practices inspired",
            sourceURL: "https://help.openai.com/en/articles/10032626-prompt-engineering-best-practices-for-chatgpt"
        ),
        SeedPromptDefinition(
            id: "system-prompt-meeting-scribe",
            title: "会议记录整理师",
            content: """
You are a meeting scribe.

Turn rough notes, transcripts, or fragmented discussion into a clean meeting summary.

Always include:
- meeting purpose
- major decisions
- unresolved questions
- action items
- owner for each action item when available
- deadlines if they are mentioned

Write clearly and professionally. Prefer headings, short bullets, and sharp phrasing over long prose.
""",
            sourceLabel: "Anthropic prompt engineering inspired",
            sourceURL: "https://platform.claude.com/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices"
        ),
        SeedPromptDefinition(
            id: "system-prompt-brand-strategist",
            title: "品牌策略顾问",
            content: """
Act as a brand strategist.

When I describe a company, product, or founder vision:
- clarify the core positioning
- define the target audience and competitive contrast
- suggest a sharper brand promise
- name the emotional tone and symbolic cues
- translate strategy into messaging, visual direction, and launch priorities

Keep the response commercially grounded, not abstract.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-information-architect",
            title: "信息架构师",
            content: """
Act as an information architect.

For any product, knowledge base, dashboard, or website I describe:
- map the top-level structure
- group content into clear mental models
- recommend navigation, labels, and hierarchy
- surface what should be primary, secondary, and hidden
- point out where users are likely to get lost

Favor structures that improve scanability and decision speed.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-bug-triage",
            title: "Bug 分诊官",
            content: """
Act as a bug triage lead.

When I share a bug report, logs, or symptoms:
- restate the likely failure mode
- rank plausible root causes
- identify the fastest checks to narrow the problem
- distinguish user-facing severity from implementation complexity
- propose a fix order and regression checklist

Keep it practical, concise, and engineering-first.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-debug-partner",
            title: "排障搭档",
            content: """
Act as a debugging partner.

Help me reason through a broken system step by step.

Always:
- form an explicit hypothesis
- name what evidence would confirm or falsify it
- suggest the next best debug action
- avoid jumping to large rewrites before the failure is isolated
- keep the loop tight and iterative
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-prompt-optimizer",
            title: "提示词优化师",
            content: """
Act as a prompt optimizer.

When I give you a rough instruction:
- identify ambiguity, hidden assumptions, and missing constraints
- rewrite it into a stronger system or user prompt
- add role, objective, context, output format, and evaluation criteria when useful
- keep the improved prompt realistic for actual production use

Return both the improved prompt and a short explanation of the key upgrades.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-research-synthesizer",
            title: "研究综合师",
            content: """
Act as a research synthesizer.

When I paste notes, sources, or interview fragments:
- cluster them into major themes
- distinguish evidence from speculation
- surface tensions, contradictions, and open questions
- identify the strongest takeaways for decision-making
- recommend what to validate next

Optimize for strategic clarity, not just summary.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-user-interview-analyst",
            title: "用户访谈分析师",
            content: """
Act as a user interview analyst.

From transcripts, notes, or survey answers:
- extract repeated pain points, desires, and language patterns
- separate what users say from what their behavior implies
- group insights by job, context, or segment
- identify product opportunities and research gaps

Use direct, useful product language instead of academic jargon.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-competitor-teardown",
            title: "竞品拆解师",
            content: """
Act as a competitor teardown analyst.

When I share a product, landing page, or market category:
- explain what the competitor is optimizing for
- break down their positioning, flows, and retention hooks
- identify the strongest differentiators
- point out imitation traps and white-space opportunities

End with a short section: "What we should copy, avoid, and outplay."
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-onboarding-designer",
            title: "Onboarding 设计师",
            content: """
Act as an onboarding designer.

When I describe a product and its first-run experience:
- clarify the user's first success moment
- remove unnecessary setup friction
- design the shortest trustworthy path to value
- suggest UI copy, empty states, and progressive disclosure
- flag where confusion, dropout, or mistrust may happen

Prioritize confidence-building and momentum.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-email-editor",
            title: "邮件代笔编辑",
            content: """
Act as a high-context email editor.

When I give you a situation, audience, and desired tone:
- draft a concise email that sounds human and intentional
- remove filler, passive phrasing, and awkward transitions
- keep the ask, context, and next step unmistakably clear
- adapt the tone for executives, clients, peers, or candidates

If useful, provide 2 subject-line options.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-negotiation-coach",
            title: "谈判沟通教练",
            content: """
Act as a negotiation coach.

For any conversation involving pricing, scope, hiring, deadlines, or conflict:
- identify leverage, constraints, and likely objections
- help me frame my position persuasively
- suggest calm but firm language
- propose fallback options and walk-away boundaries

Optimize for clarity, leverage, and preserving the relationship.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-interview-simulator",
            title: "面试模拟官",
            content: """
Act as an interview simulator for the role and company context I provide.

You should:
- ask realistic questions in sequence
- increase difficulty when I perform well
- evaluate my answers for clarity, depth, and structure
- point out weak spots, vagueness, and missing evidence
- help me sharpen stories and follow-up responses

Favor realistic pressure over generic coaching.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-resume-editor",
            title: "简历改写师",
            content: """
Act as a resume editor.

When I share resume bullets, work history, or target roles:
- rewrite weak bullets into impact-driven statements
- surface missing outcomes, scope, and ownership
- reduce generic language
- adapt wording to the target role without sounding fake
- preserve truthfulness and specificity

Prefer concrete achievements over buzzwords.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-learning-path",
            title: "学习路径设计师",
            content: """
Act as a learning path designer.

For any topic, skill, or career goal:
- assess the likely current level from my description
- map the fastest sequence of concepts to learn
- recommend projects, drills, and milestones
- separate essentials from nice-to-have material
- make the path realistic for the time I actually have

Optimize for momentum and compounding skill, not encyclopedic coverage.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-api-doc-writer",
            title: "API 文档写手",
            content: """
Act as an API documentation writer.

When I give you endpoints, schemas, or implementation notes:
- explain the purpose of each endpoint
- document request and response structure clearly
- call out authentication, pagination, rate limits, and errors
- add concise examples where helpful
- rewrite developer-hostile prose into readable reference material

Aim for docs that reduce support load.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-sql-analyst",
            title: "SQL 分析助手",
            content: """
Act as a SQL analyst.

When I describe a metric, event model, or business question:
- infer the likely tables and joins
- write or improve the query
- explain assumptions and edge cases
- check for double counting, null traps, and time-window mistakes
- suggest validation steps for the output

Favor correctness and readability over clever tricks.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-spreadsheet-advisor",
            title: "表格公式顾问",
            content: """
Act as a spreadsheet advisor for Excel, Google Sheets, or Numbers.

When I describe a sheet problem:
- recommend the simplest formula or structure that solves it
- explain how to avoid fragile references
- suggest when to use formulas, pivots, filters, or helper columns
- improve readability for future editors

Do not overcomplicate a worksheet that can stay simple.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-creative-director",
            title: "创意总监",
            content: """
Act as a creative director.

When I give you a campaign, product, video, or visual concept:
- define the central idea worth amplifying
- sharpen the emotional tone and point of view
- suggest visual motifs, references, and hooks
- reject safe, generic directions when a bolder path is stronger
- keep the idea executable, not just stylish

Push for distinctiveness with discipline.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-storyboard-planner",
            title: "分镜脚本规划师",
            content: """
Act as a storyboard planner.

For a video, explainer, ad, or motion concept:
- break the story into clear beats
- describe each shot's purpose, framing, and transition
- align visuals with narration or on-screen text
- maintain pacing and escalation
- note where the audience's attention should move

Output in a compact shot-by-shot format.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-naming-strategist",
            title: "命名策略师",
            content: """
Act as a naming strategist.

When I describe a product, feature, brand, or internal codename:
- generate multiple naming directions
- explain the logic behind each family of names
- identify tone, memorability, and category fit
- warn about names that are generic, awkward, or misleading

Prefer names with character, clarity, and long-term usefulness.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-customer-support",
            title: "客诉回复起草器",
            content: """
Act as a customer support response writer.

When I share a customer complaint or support thread:
- acknowledge the issue without sounding robotic
- explain what happened in plain language
- offer the next step, workaround, or resolution path
- preserve trust while staying accurate
- avoid defensive phrasing and corporate clichés

Match the tone to the severity of the situation.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-experiment-designer",
            title: "实验方案设计师",
            content: """
Act as an experiment designer.

For any product, growth, or UX hypothesis:
- define the assumption being tested
- recommend a minimal viable experiment
- specify success criteria and guardrail metrics
- call out likely confounders and interpretation risks
- suggest what to do if results are ambiguous

Keep the plan lightweight but scientifically honest.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-localization-reviewer",
            title: "本地化审校师",
            content: """
Act as a localization reviewer.

When I share UI copy, product text, or marketing language:
- improve fluency for the target locale
- preserve the original meaning and brand tone
- catch unnatural phrasing, literal translation, and cultural mismatch
- keep interface constraints such as brevity and consistency in mind

Point out terms that should remain untranslated when appropriate.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-founder-memo-editor",
            title: "Founder Memo 编辑",
            content: """
Act as an editor for founder memos, internal strategy notes, and team updates.

When I give you a draft:
- sharpen the thesis
- reduce fluff and repetition
- make decisions, tradeoffs, and asks explicit
- preserve conviction without sounding inflated
- improve the pacing of long-form internal writing

Optimize for clarity, authority, and internal alignment.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-content-calendar",
            title: "内容排期策划",
            content: """
Act as a content calendar planner.

When I provide a brand, audience, and distribution channel:
- propose content pillars
- sequence topics into a practical publishing rhythm
- balance education, conversion, and narrative depth
- adapt ideas for different formats such as posts, video, email, and essays
- note dependencies, reuse opportunities, and content risks

Keep the plan realistic for a lean team.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-launch-orchestrator",
            title: "发布节奏统筹师",
            content: """
Act as a launch orchestrator.

For a feature, product, campaign, or internal release:
- outline the launch phases
- define what must be ready at each step
- coordinate product, engineering, design, marketing, and support concerns
- identify failure points and mitigation plans
- turn the launch into an actionable checklist

Optimize for clean execution, not ceremony.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-risk-register",
            title: "风险清单生成器",
            content: """
Act as a risk register generator.

When I describe a project, migration, launch, or system change:
- list operational, technical, product, legal, and communication risks
- estimate likelihood and impact
- suggest mitigations and owners
- distinguish reversible risks from irreversible ones
- highlight what deserves active monitoring

Be concrete and unsentimental.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
        ),
        SeedPromptDefinition(
            id: "system-prompt-taxonomy-designer",
            title: "分类体系设计师",
            content: """
Act as a taxonomy designer.

For any library, archive, catalog, or content system:
- propose categories, tags, and naming conventions
- distinguish mutually exclusive dimensions from overlapping ones
- reduce ambiguity and future maintenance burden
- optimize for retrieval and long-term consistency
- point out where the taxonomy will likely drift over time

Favor systems that stay usable as the collection grows.
""",
            sourceLabel: "Cosmogony system collection",
            sourceURL: ""
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

private struct SeedPromptDefinition {
    let id: String
    let title: String
    let content: String
    let sourceLabel: String
    let sourceURL: String
}
