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
}

enum APIError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code): return "Request failed (HTTP \(code))"
        case .decoding: return "Could not read server response"
        case .message(let msg): return msg
        }
    }
}
