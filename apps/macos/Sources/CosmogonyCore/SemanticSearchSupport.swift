import CryptoKit
import Foundation
import GRDB

public struct SearchIntentTimeRange: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        if start <= end {
            self.start = start
            self.end = end
        } else {
            self.start = end
            self.end = start
        }
    }

    public func contains(_ date: Date) -> Bool {
        (start ... end).contains(date)
    }
}

public struct SearchIntent: Codable, Equatable, Sendable {
    public var rawQuery: String
    public var topics: [String]
    public var synonyms: [String]
    public var requiredPhrases: [String]
    public var excludedPhrases: [String]
    public var contentTypes: [String]
    public var timeRange: SearchIntentTimeRange?
    public var confidence: Double
    public var summary: String

    public init(
        rawQuery: String,
        topics: [String] = [],
        synonyms: [String] = [],
        requiredPhrases: [String] = [],
        excludedPhrases: [String] = [],
        contentTypes: [String] = [],
        timeRange: SearchIntentTimeRange? = nil,
        confidence: Double = 0,
        summary: String = ""
    ) {
        self.rawQuery = rawQuery
        self.topics = topics
        self.synonyms = synonyms
        self.requiredPhrases = requiredPhrases
        self.excludedPhrases = excludedPhrases
        self.contentTypes = contentTypes
        self.timeRange = timeRange
        self.confidence = confidence
        self.summary = summary
    }

    public var queryText: String {
        ([rawQuery] + topics + synonyms + requiredPhrases)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(queryRewrite: QueryRewrite) {
        self.init(
            rawQuery: queryRewrite.rawQuery,
            topics: queryRewrite.canonicalEntities,
            synonyms: queryRewrite.aliases,
            requiredPhrases: queryRewrite.requiredTerms,
            excludedPhrases: queryRewrite.excludedTerms,
            contentTypes: queryRewrite.languageHints,
            timeRange: queryRewrite.timeRange,
            confidence: queryRewrite.confidence,
            summary: queryRewrite.queryText
        )
    }

    public func merged(with other: SearchIntent) -> SearchIntent {
        SearchIntent(
            rawQuery: other.rawQuery.isEmpty ? rawQuery : other.rawQuery,
            topics: uniqueStrings(topics + other.topics),
            synonyms: uniqueStrings(synonyms + other.synonyms),
            requiredPhrases: uniqueStrings(requiredPhrases + other.requiredPhrases),
            excludedPhrases: uniqueStrings(excludedPhrases + other.excludedPhrases),
            contentTypes: uniqueStrings(contentTypes + other.contentTypes),
            timeRange: other.timeRange ?? timeRange,
            confidence: max(confidence, other.confidence),
            summary: other.summary.isEmpty ? summary : other.summary
        )
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values {
            let normalized = SemanticSearchToolkit.normalizedLookup(value)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }
        return ordered
    }
}

public enum AISearchStatus: Equatable, Sendable {
    case idle
    case indexing(String)
    case searching(String)
    case complete(String)
    case lexicalFallback(String)
    case semanticUnavailable(String)
    case failed(String)

    public var message: String {
        switch self {
        case .idle:
            return "Describe what you remember and Cosmogony will search the whole library."
        case let .indexing(message),
             let .searching(message),
             let .complete(message),
             let .lexicalFallback(message),
             let .semanticUnavailable(message),
             let .failed(message):
            return message
        }
    }

    public var isBusy: Bool {
        switch self {
        case .indexing, .searching:
            return true
        case .idle, .complete, .lexicalFallback, .semanticUnavailable, .failed:
            return false
        }
    }
}

public enum AISearchResultSource: String, Codable, Equatable, Sendable {
    case semantic
    case lexicalFallback
}

public enum SearchMatchedField: String, Codable, CaseIterable, Sendable {
    case exact
    case title
    case domain
    case url
    case platform
    case alias
    case category
    case tag
    case note
    case space
    case summary
    case chineseSummary
    case content
    case recency
    case semantic

    public var label: String {
        switch self {
        case .exact:
            return "精确命中"
        case .title:
            return "标题"
        case .domain:
            return "站点"
        case .url:
            return "链接"
        case .platform:
            return "平台"
        case .alias:
            return "别名"
        case .category:
            return "分类"
        case .tag:
            return "标签"
        case .note:
            return "备注"
        case .space:
            return "空间"
        case .summary:
            return "AI 摘要"
        case .chineseSummary:
            return "中文摘要"
        case .content:
            return "正文片段"
        case .recency:
            return "时间线索"
        case .semantic:
            return "语义"
        }
    }
}

public struct AISearchResult: Identifiable, Equatable, Sendable {
    public var clip: ClipItem
    public var score: Double
    public var matchedSnippet: String
    public var source: AISearchResultSource
    public var matchedFields: [SearchMatchedField]

    public init(
        clip: ClipItem,
        score: Double,
        matchedSnippet: String,
        source: AISearchResultSource,
        matchedFields: [SearchMatchedField] = []
    ) {
        self.clip = clip
        self.score = score
        self.matchedSnippet = matchedSnippet
        self.source = source
        self.matchedFields = matchedFields
    }

    public var id: String { clip.id }
}

public struct QueryRewrite: Equatable, Sendable {
    public var rawQuery: String
    public var normalizedQuery: String
    public var aliases: [String]
    public var canonicalEntities: [String]
    public var requiredTerms: [String]
    public var excludedTerms: [String]
    public var languageHints: [String]
    public var timeRange: SearchIntentTimeRange?
    public var confidence: Double

    public init(
        rawQuery: String,
        normalizedQuery: String,
        aliases: [String] = [],
        canonicalEntities: [String] = [],
        requiredTerms: [String] = [],
        excludedTerms: [String] = [],
        languageHints: [String] = [],
        timeRange: SearchIntentTimeRange? = nil,
        confidence: Double = 0
    ) {
        self.rawQuery = rawQuery
        self.normalizedQuery = normalizedQuery
        self.aliases = aliases
        self.canonicalEntities = canonicalEntities
        self.requiredTerms = requiredTerms
        self.excludedTerms = excludedTerms
        self.languageHints = languageHints
        self.timeRange = timeRange
        self.confidence = confidence
    }

    public var queryText: String {
        Self.distinctTerms([normalizedQuery] + canonicalEntities + aliases + requiredTerms).joined(separator: " ")
    }

    public var allTerms: [String] {
        Self.distinctTerms([normalizedQuery] + canonicalEntities + aliases + requiredTerms)
    }

    private static func distinctTerms(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values {
            let normalized = SemanticSearchToolkit.normalizedLookup(value)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }
        return ordered
    }
}

public struct SearchCandidate: Equatable, Sendable {
    public var clipID: String
    public var lexicalScore: Double
    public var semanticScore: Double
    public var aliasScore: Double
    public var taxonomyScore: Double
    public var recencyScore: Double
    public var exactScore: Double
    public var matchedFields: [SearchMatchedField]
    public var matchedSnippet: String

    public init(
        clipID: String,
        lexicalScore: Double = 0,
        semanticScore: Double = 0,
        aliasScore: Double = 0,
        taxonomyScore: Double = 0,
        recencyScore: Double = 0,
        exactScore: Double = 0,
        matchedFields: [SearchMatchedField] = [],
        matchedSnippet: String = ""
    ) {
        self.clipID = clipID
        self.lexicalScore = lexicalScore
        self.semanticScore = semanticScore
        self.aliasScore = aliasScore
        self.taxonomyScore = taxonomyScore
        self.recencyScore = recencyScore
        self.exactScore = exactScore
        self.matchedFields = matchedFields
        self.matchedSnippet = matchedSnippet
    }

    public var localScore: Double {
        exactScore + (lexicalScore * 0.56) + (aliasScore * 0.22) + (taxonomyScore * 0.14) + (recencyScore * 0.08)
    }

    public var rankingScore: Double {
        exactScore + (lexicalScore * 0.34) + (aliasScore * 0.18) + (taxonomyScore * 0.12) + (semanticScore * 0.28) + (recencyScore * 0.08)
    }
}

public struct SearchTraceV2: Equatable, Sendable {
    public var stageLatencies: [String: Double]
    public var candidateCounts: [String: Int]
    public var fallbackReason: String
    public var finalRankingReasons: [String]

    public init(
        stageLatencies: [String: Double] = [:],
        candidateCounts: [String: Int] = [:],
        fallbackReason: String = "",
        finalRankingReasons: [String] = []
    ) {
        self.stageLatencies = stageLatencies
        self.candidateCounts = candidateCounts
        self.fallbackReason = fallbackReason
        self.finalRankingReasons = finalRankingReasons
    }
}

public enum SearchAliasEntityType: String, Codable, CaseIterable, Sendable {
    case platform
    case domain
    case learned
}

package struct SearchAliasRule: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    package static let databaseTableName = "search_alias_rules"

    package var id: String
    package var canonical: String
    package var entityType: SearchAliasEntityType
    package var aliases: [String]
    package var isSystem: Bool
    package var updatedAt: Date

    package init(
        id: String = UUID().uuidString,
        canonical: String,
        entityType: SearchAliasEntityType,
        aliases: [String],
        isSystem: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.canonical = SemanticSearchToolkit.normalizedLookup(canonical)
        self.entityType = entityType
        self.aliases = aliases.map(SemanticSearchToolkit.normalizedLookup).filter { !$0.isEmpty }
        self.isSystem = isSystem
        self.updatedAt = updatedAt
    }

    package init(row: Row) {
        id = row["id"]
        canonical = row["canonical"] ?? ""
        entityType = SearchAliasEntityType(rawValue: row["entity_type"] ?? "") ?? .learned
        aliases = decodeStringArray(row["aliases_json"] ?? "[]")
        isSystem = row["is_system"] ?? false
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
    }

    package func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["canonical"] = SemanticSearchToolkit.normalizedLookup(canonical)
        container["entity_type"] = entityType.rawValue
        container["aliases_json"] = encodeStringArray(aliases)
        container["is_system"] = isSystem
        container["updated_at"] = updatedAt.timeIntervalSince1970
    }

    package static func systemDefaults() -> [SearchAliasRule] {
        [
            SearchAliasRule(canonical: PlatformBucket.youtube.rawValue, entityType: .platform, aliases: PlatformBucket.youtube.searchAliases, isSystem: true),
            SearchAliasRule(canonical: PlatformBucket.xPosts.rawValue, entityType: .platform, aliases: PlatformBucket.xPosts.searchAliases, isSystem: true),
            SearchAliasRule(canonical: PlatformBucket.rednote.rawValue, entityType: .platform, aliases: PlatformBucket.rednote.searchAliases, isSystem: true),
            SearchAliasRule(canonical: PlatformBucket.wechat.rawValue, entityType: .platform, aliases: PlatformBucket.wechat.searchAliases, isSystem: true),
            SearchAliasRule(canonical: PlatformBucket.douyin.rawValue, entityType: .platform, aliases: PlatformBucket.douyin.searchAliases, isSystem: true),
            SearchAliasRule(canonical: "youtube.com", entityType: .domain, aliases: ["youtube", "youtu.be", "yt", "油管"], isSystem: true),
            SearchAliasRule(canonical: "x.com", entityType: .domain, aliases: ["twitter", "tweet", "tweets", "推特", "推文"], isSystem: true),
            SearchAliasRule(canonical: "xiaohongshu.com", entityType: .domain, aliases: ["rednote", "xiaohongshu", "小红书", "红薯"], isSystem: true),
            SearchAliasRule(canonical: "douyin.com", entityType: .domain, aliases: ["douyin", "抖音"], isSystem: true),
            SearchAliasRule(canonical: "mp.weixin.qq.com", entityType: .domain, aliases: ["wechat", "weixin", "公众号", "微信"], isSystem: true)
        ]
    }
}

public struct SearchDocument: Equatable, Sendable {
    public var lexicalText: String
    public var aliasText: String
    public var summaryText: String
    public var contentText: String
    public var semanticText: String
    public var lookupText: String
}

struct ClipSearchChunk: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "clip_search_chunks"

    var id: String
    var clipID: String
    var chunkIndex: Int
    var chunkText: String
    var embeddingJSON: String
    var contentHash: String
    var profileID: String
    var modelID: String
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        clipID: String,
        chunkIndex: Int,
        chunkText: String,
        embeddingJSON: String,
        contentHash: String,
        profileID: String,
        modelID: String,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clipID = clipID
        self.chunkIndex = chunkIndex
        self.chunkText = chunkText
        self.embeddingJSON = embeddingJSON
        self.contentHash = contentHash
        self.profileID = profileID
        self.modelID = modelID
        self.updatedAt = updatedAt
    }

    init(row: Row) {
        id = row["id"]
        clipID = row["clip_id"] ?? ""
        chunkIndex = row["chunk_index"] ?? 0
        chunkText = row["chunk_text"] ?? ""
        embeddingJSON = row["embedding_json"] ?? "[]"
        contentHash = row["content_hash"] ?? ""
        profileID = row["profile_id"] ?? ""
        modelID = row["model_id"] ?? ""
        updatedAt = Date(timeIntervalSince1970: row["updated_at"] ?? Date().timeIntervalSince1970)
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["clip_id"] = clipID
        container["chunk_index"] = chunkIndex
        container["chunk_text"] = chunkText
        container["embedding_json"] = embeddingJSON
        container["content_hash"] = contentHash
        container["profile_id"] = profileID
        container["model_id"] = modelID
        container["updated_at"] = updatedAt.timeIntervalSince1970
    }

    var embedding: [Double] {
        decodeDoubleArray(embeddingJSON)
    }
}

package enum SemanticSearchToolkit {
    package static func normalizedQuery(_ query: String) -> String {
        query
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package static func normalizedLookup(_ query: String) -> String {
        normalizedQuery(query)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\s./@:_-]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package static func tokenize(_ text: String) -> [String] {
        let normalized = normalizedLookup(text)
        guard !normalized.isEmpty else { return [] }
        let parts = normalized
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map(normalizedLookup)
            .filter { !$0.isEmpty }

        if parts.count == 1, let token = parts.first, token.count > 1 {
            return [token]
        }

        return Array(NSOrderedSet(array: parts)).compactMap { $0 as? String }
    }

    package static func searchableContent(for clip: ClipItem) -> String {
        SearchDocumentBuilder.build(clip: clip).semanticText
    }

    package static func contentHash(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    package static func chunkedContent(from text: String, targetLength: Int = 1_500, overlap: Int = 220) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var chunks: [String] = []
        var cursor = normalized.startIndex

        while cursor < normalized.endIndex {
            let maxEnd = normalized.index(cursor, offsetBy: targetLength, limitedBy: normalized.endIndex) ?? normalized.endIndex
            var end = maxEnd

            if maxEnd < normalized.endIndex,
               let paragraphBreak = normalized[cursor ..< maxEnd].lastIndex(where: { $0 == "\n" || $0 == "。" || $0 == "." || $0 == "！" || $0 == "？" }) {
                end = normalized.index(after: paragraphBreak)
            }

            let chunk = normalized[cursor ..< end].trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(String(chunk))
            }

            if end == normalized.endIndex {
                break
            }

            cursor = normalized.index(end, offsetBy: -min(overlap, normalized.distance(from: cursor, to: end)), limitedBy: normalized.startIndex) ?? end
            if cursor < end {
                cursor = normalized.index(after: cursor)
            }
        }

        return Array(chunks.prefix(24))
    }

    package static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0

        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }

        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    package static func bestSnippet(for clip: ClipItem, matching chunkText: String?) -> String {
        let raw = (chunkText?.isEmpty == false ? chunkText : clip.aiSummary.isEmpty ? clip.excerpt : clip.aiSummary) ?? ""
        return compactSummary(from: raw)
    }
}

package enum SearchDocumentBuilder {
    package static func build(clip: ClipItem) -> SearchDocument {
        let readingPayload = clip.readingPayload
        let titleChinese = readingPayload?.titleChinese ?? ""
        let summaryChinese = readingPayload?.summaryChinese ?? ""
        let platformText = ([clip.platformBucket.title] + clip.platformBucket.searchAliases).joined(separator: " ")
        let urlTokens = urlLookupTokens(from: clip.url)
        let lexicalText = normalize([
            clip.title,
            clip.domain,
            urlTokens,
            clip.category,
            clip.tags.joined(separator: " "),
            clip.note,
            clip.spaceName,
            clip.platformBucket.title
        ])
        let aliasText = normalize([platformText, domainAliases(for: clip.domain), titleChinese, summaryChinese])
        let summaryText = normalize([clip.aiSummary, clip.excerpt, titleChinese, summaryChinese])
        let contentText = normalize([clip.content])
        let semanticPrefix = [
            "Title: \(clip.title)",
            "Platform: \(clip.platformBucket.title)",
            "Platform aliases: \(clip.platformBucket.searchAliases.joined(separator: ", "))",
            "Domain: \(clip.domain)",
            "URL tokens: \(urlTokens)",
            "Category: \(clip.category)",
            "Tags: \(clip.tags.joined(separator: ", "))",
            "Space: \(clip.spaceName)",
            "Note: \(clip.note)",
            "Summary: \(clip.aiSummary)",
            "Chinese title: \(titleChinese)",
            "Chinese summary: \(summaryChinese)",
            "Excerpt: \(clip.excerpt)"
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let contentSource = clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let semanticText = contentSource.isEmpty ? semanticPrefix : semanticPrefix + "\n\nFull page text:\n" + contentSource
        let lookupText = normalize([lexicalText, aliasText, summaryText, contentText])

        return SearchDocument(
            lexicalText: lexicalText,
            aliasText: aliasText,
            summaryText: summaryText,
            contentText: contentText,
            semanticText: semanticText,
            lookupText: lookupText
        )
    }

    private static func normalize(_ parts: [String]) -> String {
        SemanticSearchToolkit.normalizedLookup(parts.joined(separator: " "))
    }

    private static func urlLookupTokens(from urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return SemanticSearchToolkit.normalizedLookup(urlString)
        }

        let host = url.host ?? ""
        let hostTokens = host
            .split(separator: ".")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "www" }
        let pathTokens = url.pathComponents
            .map { $0.replacingOccurrences(of: "/", with: "") }
            .flatMap { SemanticSearchToolkit.tokenize($0) }

        return normalize(hostTokens + pathTokens)
    }

    private static func domainAliases(for domain: String) -> String {
        let normalized = SemanticSearchToolkit.normalizedLookup(domain)
        if normalized.contains("youtube") || normalized.contains("youtu") {
            return PlatformBucket.youtube.searchAliases.joined(separator: " ")
        }
        if normalized.contains("x.com") || normalized.contains("twitter") {
            return PlatformBucket.xPosts.searchAliases.joined(separator: " ")
        }
        if normalized.contains("xiaohongshu") || normalized.contains("rednote") {
            return PlatformBucket.rednote.searchAliases.joined(separator: " ")
        }
        if normalized.contains("douyin") {
            return PlatformBucket.douyin.searchAliases.joined(separator: " ")
        }
        if normalized.contains("weixin") || normalized.contains("wechat") {
            return PlatformBucket.wechat.searchAliases.joined(separator: " ")
        }
        return ""
    }
}

package enum SearchQueryRewriter {
    package static func rewrite(
        query: String,
        aliasRules: [SearchAliasRule],
        now: Date,
        timeZone: TimeZone
    ) -> QueryRewrite {
        let trimmed = SemanticSearchToolkit.normalizedQuery(query)
        let normalized = SemanticSearchToolkit.normalizedLookup(query)
        guard !normalized.isEmpty else {
            return QueryRewrite(rawQuery: trimmed, normalizedQuery: "")
        }

        let aliasIndex = buildAliasIndex(aliasRules: aliasRules)
        let quotedTerms = quotedSegments(in: trimmed)
        let excludedTerms = excludedSegments(in: trimmed)
        let baseTerms = Array(NSOrderedSet(array: [normalized] + SemanticSearchToolkit.tokenize(normalized))).compactMap { $0 as? String }

        var aliases: [String] = []
        var canonicalEntities: [String] = []
        for term in baseTerms {
            if let canonical = aliasIndex.aliasToCanonical[term] {
                canonicalEntities.append(canonical)
                aliases.append(contentsOf: aliasIndex.canonicalToAliases[canonical] ?? [])
                aliases.append(contentsOf: platformAliases(for: canonical))
                canonicalEntities.append(contentsOf: platformCanonicals(for: canonical))
            }
        }

        if let host = normalizedHostOrLookup(from: trimmed), let canonical = aliasIndex.aliasToCanonical[host] {
            canonicalEntities.append(canonical)
            aliases.append(contentsOf: aliasIndex.canonicalToAliases[canonical] ?? [])
            aliases.append(contentsOf: platformAliases(for: canonical))
            canonicalEntities.append(contentsOf: platformCanonicals(for: canonical))
        }

        let containsChinese = trimmed.range(of: #"\p{Han}"#, options: .regularExpression) != nil
        let containsLatin = trimmed.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
        var languageHints: [String] = []
        if containsChinese {
            languageHints.append("zh")
        }
        if containsLatin {
            languageHints.append("en")
        }

        let timeRange = localTimeRange(from: trimmed, now: now, timeZone: timeZone)
        let confidence: Double
        if !canonicalEntities.isEmpty || !aliases.isEmpty {
            confidence = 0.9
        } else if normalized.contains(".") || normalized.contains("/") {
            confidence = 0.82
        } else if baseTerms.count <= 2 {
            confidence = 0.72
        } else {
            confidence = 0.62
        }

        return QueryRewrite(
            rawQuery: trimmed,
            normalizedQuery: normalized,
            aliases: distinctTerms(aliases),
            canonicalEntities: distinctTerms(canonicalEntities),
            requiredTerms: distinctTerms(quotedTerms),
            excludedTerms: distinctTerms(excludedTerms),
            languageHints: distinctTerms(languageHints),
            timeRange: timeRange,
            confidence: confidence
        )
    }

    private static func buildAliasIndex(aliasRules: [SearchAliasRule]) -> (aliasToCanonical: [String: String], canonicalToAliases: [String: [String]]) {
        var aliasToCanonical: [String: String] = [:]
        var canonicalToAliases: [String: [String]] = [:]
        for rule in aliasRules {
            let canonical = SemanticSearchToolkit.normalizedLookup(rule.canonical)
            canonicalToAliases[canonical, default: []].append(canonical)
            canonicalToAliases[canonical, default: []].append(contentsOf: rule.aliases)
            aliasToCanonical[canonical] = canonical
            for alias in rule.aliases {
                let normalizedAlias = SemanticSearchToolkit.normalizedLookup(alias)
                if !normalizedAlias.isEmpty {
                    aliasToCanonical[normalizedAlias] = canonical
                }
            }
        }
        canonicalToAliases = canonicalToAliases.mapValues(distinctTerms)
        return (aliasToCanonical, canonicalToAliases)
    }

    private static func quotedSegments(in text: String) -> [String] {
        extractMatches(in: text, pattern: #""([^"]+)"|“([^”]+)”|「([^」]+)」"#)
    }

    private static func excludedSegments(in text: String) -> [String] {
        extractMatches(in: text, pattern: #"(?:^|\s)-([^\s]+)"#)
    }

    private static func extractMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            (1 ..< match.numberOfRanges)
                .compactMap { index in Range(match.range(at: index), in: text).map { String(text[$0]) } }
                .first
        }
        .map(SemanticSearchToolkit.normalizedLookup)
        .filter { !$0.isEmpty }
    }

    private static func normalizedHostOrLookup(from text: String) -> String? {
        if let url = URL(string: text), let host = url.host {
            return SemanticSearchToolkit.normalizedLookup(host)
        }

        let normalized = SemanticSearchToolkit.normalizedLookup(text)
        if normalized.contains("."), !normalized.contains(" ") {
            return normalized
        }
        return nil
    }

    private static func distinctTerms(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values {
            let normalized = SemanticSearchToolkit.normalizedLookup(value)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }
        return ordered
    }

    private static func platformCanonicals(for canonical: String) -> [String] {
        switch canonical {
        case let value where value.contains("youtube"):
            return [PlatformBucket.youtube.rawValue]
        case let value where value.contains("x.com") || value.contains("twitter"):
            return [PlatformBucket.xPosts.rawValue]
        case let value where value.contains("xiaohongshu") || value.contains("rednote"):
            return [PlatformBucket.rednote.rawValue]
        case let value where value.contains("douyin"):
            return [PlatformBucket.douyin.rawValue]
        case let value where value.contains("weixin") || value.contains("wechat"):
            return [PlatformBucket.wechat.rawValue]
        default:
            return []
        }
    }

    private static func platformAliases(for canonical: String) -> [String] {
        switch canonical {
        case let value where value.contains("youtube"):
            return PlatformBucket.youtube.searchAliases
        case let value where value.contains("x.com") || value.contains("twitter"):
            return PlatformBucket.xPosts.searchAliases
        case let value where value.contains("xiaohongshu") || value.contains("rednote"):
            return PlatformBucket.rednote.searchAliases
        case let value where value.contains("douyin"):
            return PlatformBucket.douyin.searchAliases
        case let value where value.contains("weixin") || value.contains("wechat"):
            return PlatformBucket.wechat.searchAliases
        default:
            return []
        }
    }

    private static func localTimeRange(from query: String, now: Date, timeZone: TimeZone) -> SearchIntentTimeRange? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        if query.contains("昨天"), let day = calendar.date(byAdding: .day, value: -1, to: now), let interval = calendar.dateInterval(of: .day, for: day) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        if query.contains("前天"), let day = calendar.date(byAdding: .day, value: -2, to: now), let interval = calendar.dateInterval(of: .day, for: day) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        if query.contains("今天"), let interval = calendar.dateInterval(of: .day, for: now) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        if query.contains("上周"),
           let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
           let previousWeek = calendar.date(byAdding: .day, value: -7, to: thisWeek.start),
           let interval = calendar.dateInterval(of: .weekOfYear, for: previousWeek) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        if (query.contains("这个月") || query.contains("本月")),
           let interval = calendar.dateInterval(of: .month, for: now) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        return nil
    }
}

public func encodeDoubleArray(_ values: [Double]) -> String {
    let data = (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    return String(data: data, encoding: .utf8) ?? "[]"
}

public func decodeDoubleArray(_ value: String) -> [Double] {
    guard let data = value.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([Double].self, from: data)) ?? []
}
