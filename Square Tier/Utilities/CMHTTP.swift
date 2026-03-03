import Foundation

enum CMHTTP {
    static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        return URLSession(configuration: cfg)
    }()

    @discardableResult
    static func applyAuthHeaders(_ request: inout URLRequest) -> Bool {
        let key = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }

        // Ensure requests don't carry stale auth headers from prior mutations.
        request.setValue(nil, forHTTPHeaderField: "x-api-key")
        request.setValue(nil, forHTTPHeaderField: "Authorization")

        switch AppConfig.authHeaderMode {
        case .apiKey:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        case .bearer:
            let token: String
            if key.lowercased().hasPrefix("bearer ") {
                token = String(key.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                token = key
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return true
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding
    case rateLimited(retryAfter: TimeInterval?)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code):
            if code == 429 {
                return "Service is temporarily busy. Please try again shortly."
            }
            if code >= 500 {
                return "Service is temporarily unavailable. Please try again shortly."
            }
            return "Request failed. Please try again."
        case .decoding: return "Could not read server response"
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                return "Rewards are temporarily busy. Please wait \(Int(ceil(retryAfter))) seconds and tap Refresh again."
            }
            return "Rewards are temporarily busy. Please wait a moment and tap Refresh again."
        case .message(let msg):
            let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Request failed. Please try again."
            }
            let lower = trimmed.lowercased()
            if trimmed.first == "{" || trimmed.first == "[" || lower.contains("http ") || lower.contains("https://") {
                return "Request failed. Please try again."
            }
            return trimmed
        }
    }
}
