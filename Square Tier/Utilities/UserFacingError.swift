import Foundation

enum UserFacingErrorContext {
    case auth
    case rewards
    case events
    case wallet
    case accountDeletion
    case generic
}

enum UserFacingError {
    static func message(for error: Error, context: UserFacingErrorContext, fallback: String) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited(let retryAfter):
                if let retryAfter, retryAfter > 0 {
                    return "Service is busy right now. Please try again in \(Int(ceil(retryAfter))) seconds."
                }
                return "Service is busy right now. Please try again in a moment."
            case .invalidURL, .decoding:
                break
            case .badStatus(let code):
                if code == 401 || code == 403 {
                    return authorizationMessage(for: context)
                }
                if code >= 500 {
                    return "Service is temporarily unavailable. Please try again shortly."
                }
            case .message(let raw):
                if let clean = sanitize(raw) {
                    return clean
                }
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please reconnect and try again."
            case .timedOut:
                return "Request timed out. Please try again."
            default:
                break
            }
        }

        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if let clean = sanitize(localized) {
            return clean
        }
        return fallback
    }

    private static func authorizationMessage(for context: UserFacingErrorContext) -> String {
        switch context {
        case .auth:
            return "Sign-in is unavailable right now. Please try again."
        case .rewards, .wallet:
            return "Rewards access is unavailable right now."
        case .accountDeletion:
            return "Account deletion is unavailable right now. Please contact support."
        case .events, .generic:
            return "Service is unavailable right now."
        }
    }

    private static func sanitize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let isMachineCodeToken =
            trimmed.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil
            || trimmed.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
        if trimmed.first == "{" || trimmed.first == "[" {
            return nil
        }
        if isMachineCodeToken && (trimmed.contains("_") || trimmed.contains("-")) {
            return nil
        }
        if lower.contains("http://")
            || lower.contains("https://")
            || lower.contains("http ")
            || lower.contains("status ")
            || lower.contains("statuscode")
            || lower == "rate_limited"
            || lower.contains("rate_limit_error")
            || lower == "invalid_request_error"
            || lower == "unauthorized"
            || lower == "not_found"
            || lower == "invalid_phone_number"
            || lower.contains("no http response")
            || lower == "invalid url"
            || lower.contains("could not read server response")
            || lower.contains("backendbaseurl")
            || lower.contains("urlsession")
            || lower.contains("nsurl")
            || lower.contains("json")
            || lower.contains("decoding")
            || lower.contains("from https") {
            return nil
        }

        return trimmed
    }
}
