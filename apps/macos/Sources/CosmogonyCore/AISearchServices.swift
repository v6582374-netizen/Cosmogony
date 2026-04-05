import Foundation

struct EmbeddingService: Sendable {
    func embed(texts: [String], profile: ProviderProfile, apiKey: String) async throws -> [[Double]] {
        let cleaned = texts.map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return [] }

        let secret = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else {
            throw NSError(domain: "Cosmogony.Embedding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing embedding API key."])
        }

        guard let request = buildRequest(profile: profile, apiKey: secret, texts: cleaned) else {
            throw NSError(domain: "Cosmogony.Embedding", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid embedding provider URL."])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Cosmogony.Embedding", code: 3, userInfo: [NSLocalizedDescriptionKey: "No embedding HTTP response."])
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(decoding: data.prefix(280), as: UTF8.self)
            throw NSError(domain: "Cosmogony.Embedding", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: body.isEmpty ? "Embedding request failed." : body])
        }

        let vectors = try parseEmbeddings(from: data, kind: profile.kind)
        guard vectors.count == cleaned.count else {
            throw NSError(domain: "Cosmogony.Embedding", code: 4, userInfo: [NSLocalizedDescriptionKey: "Embedding count mismatch."])
        }
        return vectors
    }

    private func buildRequest(profile: ProviderProfile, apiKey: String, texts: [String]) -> URLRequest? {
        let trimmedBaseURL = profile.resolvedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let model = profile.embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return nil }

        switch profile.kind {
        case .claude:
            return nil
        case .openAI, .deepseek, .minimax, .openAICompatible:
            guard let url = URL(string: "\(trimmedBaseURL)/v1/embeddings") else { return nil }
            var request = URLRequest(url: url)
            request.timeoutInterval = 45
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = [
                "model": model,
                "input": texts
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            return request
        case .gemini:
            let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
            guard let url = URL(string: "\(trimmedBaseURL)/v1beta/models/\(model):batchEmbedContents?key=\(encodedKey)") else { return nil }
            var request = URLRequest(url: url)
            request.timeoutInterval = 45
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let requests = texts.map { text in
                [
                    "content": [
                        "parts": [["text": text]]
                    ]
                ]
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["requests": requests])
            return request
        }
    }

    private func parseEmbeddings(from data: Data, kind: ProviderKind) throws -> [[Double]] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        switch kind {
        case .claude:
            throw NSError(domain: "Cosmogony.Embedding", code: 5, userInfo: [NSLocalizedDescriptionKey: "Claude embeddings are not supported in Cosmogony yet."])
        case .openAI, .deepseek, .minimax, .openAICompatible:
            let items = json["data"] as? [[String: Any]] ?? []
            return items.compactMap { item in
                item["embedding"] as? [Double]
            }
        case .gemini:
            let items = json["embeddings"] as? [[String: Any]] ?? []
            return items.compactMap { item in
                item["values"] as? [Double]
            }
        }
    }
}

struct AIQueryIntentService: Sendable {
    func parseIntent(
        query: String,
        now: Date,
        timeZone: TimeZone,
        profile: ProviderProfile?,
        apiKey: String?
    ) async -> SearchIntent {
        let normalized = SemanticSearchToolkit.normalizedQuery(query)
        guard !normalized.isEmpty else {
            return SearchIntent(rawQuery: "")
        }

        if let profile, let apiKey {
            do {
                let prompt = buildPrompt(query: normalized, now: now, timeZone: timeZone)
                let request = try buildTextGenerationRequest(
                    profile: profile,
                    apiKey: apiKey,
                    systemPrompt: "You convert natural-language memory-like search queries into strict JSON for semantic retrieval.",
                    userPrompt: prompt,
                    temperature: 0.1,
                    maxTokens: 500
                )
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    return heuristicIntent(query: normalized, now: now, timeZone: timeZone)
                }
                let rawText = try parseGeneratedText(from: data, kind: profile.kind)
                if let intent = parseIntentJSON(rawText, rawQuery: normalized) {
                    return intent
                }
            } catch {
                return heuristicIntent(query: normalized, now: now, timeZone: timeZone)
            }
        }

        return heuristicIntent(query: normalized, now: now, timeZone: timeZone)
    }

    private func buildPrompt(query: String, now: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone

        return """
        Return JSON only.
        Interpret the user's memory-like search request for a knowledge clip library.
        Current local datetime: \(formatter.string(from: now))
        Current timezone identifier: \(timeZone.identifier)

        Output schema:
        {
          "topics": ["topic"],
          "synonyms": ["related phrase"],
          "required_phrases": ["must-have phrase"],
          "excluded_phrases": ["must-not-have phrase"],
          "content_types": ["article|video|tweet|plugin|tutorial|page"],
          "time_range_start": "ISO8601 or empty",
          "time_range_end": "ISO8601 or empty",
          "confidence": 0.0,
          "summary": "short explanation"
        }

        Requirements:
        - Resolve relative time references like "上个月8号左右", "上周", "昨天" into explicit ISO8601 timestamps.
        - When the query says "around" or "左右", use a reasonable fuzzy window.
        - Topics and synonyms should focus on semantic retrieval over full page text, not titles only.
        - Keep arrays short and high-signal.

        User query:
        \(query)
        """
    }

    private func parseIntentJSON(_ rawText: String, rawQuery: String) -> SearchIntent? {
        guard
            let jsonString = extractJSONObject(from: rawText),
            let data = jsonString.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let topics = (object["topics"] as? [String] ?? []).map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        let synonyms = (object["synonyms"] as? [String] ?? []).map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        let requiredPhrases = (object["required_phrases"] as? [String] ?? []).map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        let excludedPhrases = (object["excluded_phrases"] as? [String] ?? []).map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        let contentTypes = (object["content_types"] as? [String] ?? []).map(SemanticSearchToolkit.normalizedQuery).filter { !$0.isEmpty }
        let confidence = max(0, min(1, object["confidence"] as? Double ?? 0.55))
        let summary = (object["summary"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let start = parseISO8601(object["time_range_start"] as? String)
        let end = parseISO8601(object["time_range_end"] as? String)
        let timeRange = start.flatMap { startDate in
            end.map { SearchIntentTimeRange(start: startDate, end: $0) }
        }

        return SearchIntent(
            rawQuery: rawQuery,
            topics: topics,
            synonyms: synonyms,
            requiredPhrases: requiredPhrases,
            excludedPhrases: excludedPhrases,
            contentTypes: contentTypes,
            timeRange: timeRange,
            confidence: confidence,
            summary: summary
        )
    }

    private func heuristicIntent(query: String, now: Date, timeZone: TimeZone) -> SearchIntent {
        let lowercased = query.lowercased()
        let tokens = lowercased
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map(SemanticSearchToolkit.normalizedQuery)
            .filter { !$0.isEmpty && $0.count > 1 }

        let topics = Array(NSOrderedSet(array: tokens)).compactMap { $0 as? String }
        return SearchIntent(
            rawQuery: query,
            topics: topics,
            synonyms: inferredSynonyms(from: lowercased),
            timeRange: heuristicTimeRange(from: query, now: now, timeZone: timeZone),
            confidence: 0.42,
            summary: "Fallback heuristic intent parsing."
        )
    }

    private func inferredSynonyms(from query: String) -> [String] {
        var values: [String] = []
        if query.contains("插件") || query.contains("plugin") || query.contains("extension") {
            values.append(contentsOf: ["plugin", "extension", "插件"])
        }
        if query.contains("文章") || query.contains("page") || query.contains("article") {
            values.append(contentsOf: ["article", "page", "文章"])
        }
        if query.contains("视频") || query.contains("video") {
            values.append(contentsOf: ["video", "视频"])
        }
        return Array(NSOrderedSet(array: values)).compactMap { $0 as? String }
    }

    private func heuristicTimeRange(from query: String, now: Date, timeZone: TimeZone) -> SearchIntentTimeRange? {
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
        if query.contains("这个月") || query.contains("本月"),
           let interval = calendar.dateInterval(of: .month, for: now) {
            return SearchIntentTimeRange(start: interval.start, end: interval.end)
        }
        if query.contains("上个月"),
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: now),
           let monthInterval = calendar.dateInterval(of: .month, for: previousMonth) {
            if let dayNumber = extractChineseDayNumber(from: query) {
                var components = calendar.dateComponents([.year, .month], from: previousMonth)
                components.day = dayNumber
                components.hour = 12
                if let center = calendar.date(from: components) {
                    let fuzzyStart = calendar.date(byAdding: .day, value: -2, to: center) ?? monthInterval.start
                    let fuzzyEnd = calendar.date(byAdding: .day, value: 2, to: center) ?? monthInterval.end
                    return SearchIntentTimeRange(start: max(fuzzyStart, monthInterval.start), end: min(fuzzyEnd, monthInterval.end))
                }
            }
            return SearchIntentTimeRange(start: monthInterval.start, end: monthInterval.end)
        }
        return nil
    }

    private func extractChineseDayNumber(from text: String) -> Int? {
        let pattern = #"(?:(?:上个月|上月)\s*)(\d{1,2})\s*(?:号|日)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[valueRange])
    }
}

struct AIRerankCandidate: Sendable {
    var clipID: String
    var title: String
    var url: String
    var domain: String
    var capturedAt: Date
    var snippet: String
    var vectorScore: Double
}

struct AIRerankDecision: Sendable {
    var clipID: String
    var score: Double
    var snippet: String
}

struct AIRerankService: Sendable {
    func rerank(
        query: String,
        intent: SearchIntent,
        candidates: [AIRerankCandidate],
        profile: ProviderProfile?,
        apiKey: String?
    ) async -> [AIRerankDecision] {
        guard !candidates.isEmpty else { return [] }

        guard let profile, let apiKey else {
            return candidates
                .sorted { $0.vectorScore > $1.vectorScore }
                .map { AIRerankDecision(clipID: $0.clipID, score: $0.vectorScore, snippet: $0.snippet) }
        }

        do {
            let prompt = buildPrompt(query: query, intent: intent, candidates: candidates)
            let request = try buildTextGenerationRequest(
                profile: profile,
                apiKey: apiKey,
                systemPrompt: "You rerank search candidates for a clip library and return strict JSON only.",
                userPrompt: prompt,
                temperature: 0.1,
                maxTokens: 900
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return candidates
                    .sorted { $0.vectorScore > $1.vectorScore }
                    .map { AIRerankDecision(clipID: $0.clipID, score: $0.vectorScore, snippet: $0.snippet) }
            }
            let rawText = try parseGeneratedText(from: data, kind: profile.kind)
            guard let decisions = parseDecisions(rawText), !decisions.isEmpty else {
                return candidates
                    .sorted { $0.vectorScore > $1.vectorScore }
                    .map { AIRerankDecision(clipID: $0.clipID, score: $0.vectorScore, snippet: $0.snippet) }
            }
            return decisions
        } catch {
            return candidates
                .sorted { $0.vectorScore > $1.vectorScore }
                .map { AIRerankDecision(clipID: $0.clipID, score: $0.vectorScore, snippet: $0.snippet) }
        }
    }

    private func buildPrompt(query: String, intent: SearchIntent, candidates: [AIRerankCandidate]) -> String {
        let formatter = ISO8601DateFormatter()
        let candidateText = candidates.enumerated().map { index, candidate in
            """
            Candidate \(index + 1)
            clip_id: \(candidate.clipID)
            title: \(candidate.title)
            url: \(candidate.url)
            domain: \(candidate.domain)
            captured_at: \(formatter.string(from: candidate.capturedAt))
            semantic_score: \(String(format: "%.4f", candidate.vectorScore))
            matched_snippet: \(candidate.snippet)
            """
        }.joined(separator: "\n\n")

        return """
        Return JSON only.
        Rerank candidates for this user query over saved clips.

        User query:
        \(query)

        Parsed intent summary:
        \(intent.summary.isEmpty ? intent.queryText : intent.summary)

        Output schema:
        {
          "results": [
            {
              "clip_id": "string",
              "score": 0.0,
              "snippet": "best matching evidence from the page text"
            }
          ]
        }

        Rules:
        - Score between 0 and 1.
        - Prefer candidates whose matched snippet clearly answers the memory-like query.
        - Use full-page-text evidence in the snippet field; do not use title-only reasoning.
        - If time hints exist, prefer candidates captured inside or near the requested time window.
        - Return at most \(min(candidates.count, 16)) results, highest score first.

        Candidates:
        \(candidateText)
        """
    }

    private func parseDecisions(_ rawText: String) -> [AIRerankDecision]? {
        guard
            let jsonString = extractJSONObject(from: rawText),
            let data = jsonString.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawResults = object["results"] as? [[String: Any]]
        else {
            return nil
        }

        return rawResults.compactMap { row in
            guard let clipID = row["clip_id"] as? String, !clipID.isEmpty else {
                return nil
            }
            let score = max(0, min(1, row["score"] as? Double ?? 0))
            let snippet = (row["snippet"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return AIRerankDecision(clipID: clipID, score: score, snippet: snippet)
        }
    }
}

private func buildTextGenerationRequest(
    profile: ProviderProfile,
    apiKey: String,
    systemPrompt: String,
    userPrompt: String,
    temperature: Double,
    maxTokens: Int
) throws -> URLRequest {
    let trimmedBaseURL = profile.resolvedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    let secret = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !secret.isEmpty else {
        throw NSError(domain: "Cosmogony.AIText", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API key."])
    }

    switch profile.kind {
    case .openAI, .deepseek, .minimax, .openAICompatible:
        guard let url = URL(string: "\(trimmedBaseURL)/v1/chat/completions") else {
            throw NSError(domain: "Cosmogony.AIText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid provider URL."])
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": profile.defaultModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : profile.defaultModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": temperature,
            "response_format": ["type": "json_object"],
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    case .claude:
        guard let url = URL(string: "\(trimmedBaseURL)/v1/messages") else {
            throw NSError(domain: "Cosmogony.AIText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid provider URL."])
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secret, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": profile.defaultModel,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    case .gemini:
        let model = profile.defaultModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gemini-1.5-flash" : profile.defaultModel
        let encodedKey = secret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? secret
        guard let url = URL(string: "\(trimmedBaseURL)/v1beta/models/\(model):generateContent?key=\(encodedKey)") else {
            throw NSError(domain: "Cosmogony.AIText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid provider URL."])
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": systemPrompt + "\n\n" + userPrompt]]]
            ],
            "generationConfig": [
                "temperature": temperature,
                "responseMimeType": "application/json"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

private func parseGeneratedText(from data: Data, kind: ProviderKind) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    switch kind {
    case .openAI, .deepseek, .minimax, .openAICompatible:
        let choices = json["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = (message?["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw NSError(domain: "Cosmogony.AIText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Generated text was empty."])
        }
        return content
    case .claude:
        let content = json["content"] as? [[String: Any]]
        let text = (content?.first?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "Cosmogony.AIText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Generated text was empty."])
        }
        return text
    case .gemini:
        let candidates = json["candidates"] as? [[String: Any]]
        let candidate = candidates?.first?["content"] as? [String: Any]
        let parts = candidate?["parts"] as? [[String: Any]]
        let text = (parts?.first?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "Cosmogony.AIText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Generated text was empty."])
        }
        return text
    }
}

private func parseISO8601(_ value: String?) -> Date? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return ISO8601DateFormatter().date(from: value)
}

private func extractJSONObject(from text: String) -> String? {
    guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
        return nil
    }
    return String(text[start ... end])
}
