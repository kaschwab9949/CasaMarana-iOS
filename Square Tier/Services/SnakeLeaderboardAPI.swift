import Foundation

private enum HTTP {
    static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        return URLSession(configuration: cfg)
    }()
}

struct SnakeLeaderboardEntry: Decodable, Identifiable {
    let rank: Int
    let displayName: String
    let score: Int
    let isCurrentUser: Bool

    var id: String { "\(rank)-\(displayName)-\(score)" }

    private enum CodingKeys: String, CodingKey {
        case rank
        case displayName
        case score
        case isCurrentUser
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = (try? container.decode(Int.self, forKey: .rank)) ?? 0
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? "Member"
        score = (try? container.decode(Int.self, forKey: .score)) ?? 0
        isCurrentUser = (try? container.decode(Bool.self, forKey: .isCurrentUser)) ?? false
    }
}

private struct SnakeLeaderboardResponse: Decodable {
    let entries: [SnakeLeaderboardEntry]
}

private struct SnakeScoreSubmitRequest: Encodable {
    let phone: String
    let displayName: String
    let score: Int
}

private struct SnakeScoreSubmitResponse: Decodable {
    let highScore: Int?
}

final class SnakeLeaderboardAPI {
    private func applyAuthHeaders(_ request: inout URLRequest) throws {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Only set Content-Type for requests with a body; callers may set it themselves for GETs.
        if request.httpMethod != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        guard CMHTTP.applyAuthHeaders(&request) else {
            throw APIError.message("Leaderboard service is not configured. Add an API key in Settings.")
        }
    }

    private func retryAfterSeconds(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let value = response?.value(forHTTPHeaderField: "Retry-After") else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = TimeInterval(trimmed), seconds > 0 else { return nil }
        return seconds
    }

    private func parseErrorMessage(from data: Data, statusCode: Int, response: HTTPURLResponse?) -> APIError {
        let raw = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerRaw = raw.lowercased()
        var retryAfter = retryAfterSeconds(from: response)
        let defaultRateLimitDelay: TimeInterval = 60

        if statusCode == 429 {
            return .message("Too many requests. Please try again in \(Int((retryAfter ?? defaultRateLimitDelay).rounded())) seconds.")
        }
        if statusCode == 401 || statusCode == 403 {
            if AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .message("Leaderboard service is not configured. Add your API key and try again.")
            }
            return .message("Leaderboard service rejected this credential. Verify API settings and try again.")
        }
        if statusCode == 404 {
            return .message("Leaderboard route is unavailable. Verify backend URL and deployment.")
        }
        if lowerRaw.contains("<!doctype html") || lowerRaw.contains("<html") {
            return .message("Leaderboard service returned an unexpected response. Verify backend URL and API route.")
        }

        var messageCandidates: [String] = []
        var hasRateLimitSignal = false

        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let retry = object["retry_after"] as? Int, retry > 0 {
                retryAfter = TimeInterval(retry)
            } else if let retry = object["retry_after"] as? Double, retry > 0 {
                retryAfter = retry
            }

            if let msg = object["message"] as? String {
                messageCandidates.append(msg)
            }
            if let err = object["error"] as? String {
                messageCandidates.append(err)
            }
            if let detail = object["detail"] as? String {
                messageCandidates.append(detail)
            }
            if let detailsText = object["details"] as? String {
                messageCandidates.append(detailsText)

                if let detailsData = detailsText.data(using: .utf8),
                   let detailsObj = try? JSONSerialization.jsonObject(with: detailsData, options: []) as? [String: Any],
                   let errors = detailsObj["errors"] as? [[String: Any]] {
                    for item in errors {
                        if let code = item["code"] as? String { messageCandidates.append(code) }
                        if let category = item["category"] as? String { messageCandidates.append(category) }
                        if let detail = item["detail"] as? String { messageCandidates.append(detail) }
                    }
                }
            }

            if let detailsObj = object["details"] as? [String: Any],
               let errors = detailsObj["errors"] as? [[String: Any]] {
                for item in errors {
                    if let code = item["code"] as? String { messageCandidates.append(code) }
                    if let category = item["category"] as? String { messageCandidates.append(category) }
                    if let detail = item["detail"] as? String { messageCandidates.append(detail) }
                }
            }
        }

        let combinedSignals = messageCandidates.joined(separator: " ").lowercased()
        hasRateLimitSignal =
            combinedSignals.contains("rate_limited")
            || combinedSignals.contains("rate limit")
            || combinedSignals.contains("exceeded the number of requests")
            || lowerRaw.contains("rate_limited")
            || lowerRaw.contains("rate limit")
            || lowerRaw.contains("exceeded the number of requests")

        if hasRateLimitSignal {
            return .message("Too many requests. Please try again in \(Int((retryAfter ?? defaultRateLimitDelay).rounded())) seconds.")
        }

        let firstReadable = messageCandidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { candidate in
                guard !candidate.isEmpty else { return false }
                guard candidate.first != "{" && candidate.first != "[" else { return false }
                let lowered = candidate.lowercased()
                if lowered == "rate_limited" || lowered == "rate_limit_error" {
                    return false
                }
                let looksLikeCode =
                    candidate.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil
                    || candidate.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
                if looksLikeCode && (candidate.contains("_") || candidate.contains("-")) {
                    return false
                }
                return true
            }

        if let readable = firstReadable, !readable.isEmpty {
            return .message(readable)
        }

        if !raw.isEmpty {
            if raw.first == "{" || raw.first == "[" {
                return .message("Leaderboard is unavailable right now. Please try again shortly.")
            }
            return .message(raw)
        }

        return .badStatus(statusCode)
    }

    func fetchLeaderboard(limit: Int = 100, phoneE164: String?) async throws -> [SnakeLeaderboardEntry] {
        let endpoint = BackendRoute.url(for: BackendRoute.snakeLeaderboard)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(max(1, min(100, limit))))]
        if let phoneE164, !phoneE164.isEmpty {
            queryItems.append(URLQueryItem(name: "phone", value: phoneE164))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try applyAuthHeaders(&request)

        let (data, response) = try await HTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw parseErrorMessage(from: data, statusCode: http.statusCode, response: http)
        }

        do {
            return try JSONDecoder().decode(SnakeLeaderboardResponse.self, from: data).entries
        } catch {
            throw APIError.decoding
        }
    }

    @discardableResult
    func submitScore(phoneE164: String, displayName: String, score: Int) async throws -> Int {
        let endpoint = BackendRoute.url(for: BackendRoute.snakeScore)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)

        let payload = SnakeScoreSubmitRequest(
            phone: phoneE164,
            displayName: displayName,
            score: max(0, score)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await HTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw parseErrorMessage(from: data, statusCode: http.statusCode, response: http)
        }

        let decoded = try? JSONDecoder().decode(SnakeScoreSubmitResponse.self, from: data)
        return decoded?.highScore ?? max(0, score)
    }
}
