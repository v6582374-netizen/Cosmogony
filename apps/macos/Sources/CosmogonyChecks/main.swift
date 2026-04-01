import CosmogonyCore
import Foundation

@main
struct CosmogonyChecks {
    static func main() {
        do {
            try verifyPlatforms()
            try verifyTimebox()
            try verifyProviders()
            try verifyShortcuts()
            try verifyChineseTextDetection()
            try verifySiteIconResolver()
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
        try assert(SearchScorer.mode(settings: settings, profiles: [lexicalOnly, embeddingReady]) == .embeddingReady, "Embedding profile should enable embedding-ready mode")
    }

    private static func verifyShortcuts() throws {
        let conflict = ShortcutSettings(
            captureCurrentPage: .captureCurrentPageDefault,
            captureClipboard: .captureCurrentPageDefault
        )
        try assert(conflict.conflictMessage() != nil, "Duplicate shortcuts must be rejected")
    }

    private static func verifyChineseTextDetection() throws {
        try assert(CosmoTextClassifier.containsChinese("中文标题"), "Chinese text should be detected")
        try assert(!CosmoTextClassifier.containsChinese("Cosmogony Search"), "ASCII-only text should not be detected as Chinese")
    }

    private static func verifySiteIconResolver() throws {
        try assert(SiteIconResolver.normalizedHost(from: "https://www.Example.com/path?q=1") == "example.com", "Hosts should be normalized and lowercase without www")
        try assert(SiteIconResolver.normalizedHost(from: "clipboard://local") == nil, "Non-web URLs should not produce a host")
        try assert(SiteIconResolver.fallbackIconURL(for: "example.com")?.absoluteString == "https://example.com/favicon.ico", "Fallback favicon URL should be stable")
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
