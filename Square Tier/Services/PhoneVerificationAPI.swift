import Foundation

struct PhoneVerificationStartResponse: Decodable {
    /// Opaque id for this verification attempt.
    let requestId: String

    private enum CodingKeys: String, CodingKey {
        case requestId
        case requestID = "request_id"
        case id
    }

    init(requestId: String) {
        self.requestId = requestId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolved =
            (try? container.decodeIfPresent(String.self, forKey: .requestId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .requestID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? ""
        requestId = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PhoneVerificationVerifyResponse: Decodable {
    let verified: Bool
    /// Optional long-lived token proving verification.
    let token: String?

    private enum CodingKeys: String, CodingKey {
        case verified
        case isVerified = "is_verified"
        case token
    }

    init(verified: Bool, token: String?) {
        self.verified = verified
        self.token = token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let boolValue = ((try? container.decodeIfPresent(Bool.self, forKey: .verified)) ?? nil) {
            verified = boolValue
        } else if let boolValue = ((try? container.decodeIfPresent(Bool.self, forKey: .isVerified)) ?? nil) {
            verified = boolValue
        } else if let stringValue = ((try? container.decodeIfPresent(String.self, forKey: .verified)) ?? nil) {
            let lowered = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            verified = lowered == "true" || lowered == "1" || lowered == "yes"
        } else {
            verified = false
        }

        token = ((try? container.decodeIfPresent(String.self, forKey: .token)) ?? nil)
    }
}

final class PhoneVerificationAPI {
    private func shouldTryFallback(statusCode: Int, currentIndex: Int, total: Int) -> Bool {
        guard currentIndex < total - 1 else { return false }
        return statusCode == 404 || statusCode == 405
    }

    private func makeJSONRequest(pathComponents: [String], body: [String: Any]) throws -> URLRequest {
        let url = BackendRoute.url(for: pathComponents)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    private func applyAuthHeaders(_ request: inout URLRequest) throws {
        guard CMHTTP.applyAuthHeaders(&request) else {
            throw APIError.message("Verification service is not configured. Add an API key in Settings.")
        }
    }

    private static let isoFormatter: DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        d.timeZone = TimeZone(secondsFromGMT: 0)
        return d
    }()

    private func friendlyStatusMessage(statusCode: Int, data: Data, operation: String) -> String {
        if statusCode == 429 {
            return "Too many verification attempts. Please wait a moment and try again."
        }
        if statusCode == 401 || statusCode == 403 {
            if AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Verification service is not configured. Add your API key and try again."
            }
            return "Verification service rejected this credential. Please verify API settings."
        }
        if statusCode == 404 {
            return "Verification service route is unavailable. Please verify backend URL."
        }

        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let fields = ["message", "error", "detail"]
            for field in fields {
                if let raw = object[field] as? String {
                    let sanitized = UserFacingError.message(
                        for: APIError.message(raw),
                        context: .auth,
                        fallback: ""
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sanitized.isEmpty {
                        return sanitized
                    }
                }
            }
        }

        let raw = String(decoding: data, as: UTF8.self).lowercased()
        if raw.contains("<!doctype html") || raw.contains("<html") {
            return "Verification service returned an unexpected response. Please verify backend URL."
        }

        if statusCode == 401 || statusCode == 403 {
            return "Verification service is unavailable right now."
        }
        if statusCode >= 500 {
            return "Verification service is temporarily unavailable. Please try again."
        }
        return "Could not \(operation). Please check the number and try again."
    }

    func start(phoneE164: String) async throws -> PhoneVerificationStartResponse {
        let body: [String: Any] = [
            "phone": phoneE164,
            "phone_e164": phoneE164,
            "phoneE164": phoneE164
        ]

        let candidates = BackendRoute.phoneStartCandidates
        for (index, path) in candidates.enumerated() {
            let request = try makeJSONRequest(pathComponents: path, body: body)
            let (data, response) = try await CMHTTP.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

            guard (200..<300).contains(http.statusCode) else {
                if shouldTryFallback(statusCode: http.statusCode, currentIndex: index, total: candidates.count) {
                    continue
                }
                throw APIError.message(friendlyStatusMessage(statusCode: http.statusCode, data: data, operation: "send verification code"))
            }

            let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            if contentType.contains("text/html") {
                throw APIError.message("Verification service is unavailable right now. Please try again.")
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(Self.isoFormatter)
                let parsed = try decoder.decode(PhoneVerificationStartResponse.self, from: data)
                if !parsed.requestId.isEmpty {
                    return parsed
                }
                throw APIError.message("Verification service returned an empty request ID. Please try again.")
            } catch {
                throw APIError.message("Verification service returned an unexpected response. Please try again.")
            }
        }

        throw APIError.message("Verification service route is unavailable. Please verify backend URL.")
    }

    func verify(phoneE164: String, code: String, requestId: String) async throws -> PhoneVerificationVerifyResponse {
        let body: [String: Any] = [
            "phone": phoneE164,
            "phone_e164": phoneE164,
            "phoneE164": phoneE164,
            "code": code,
            "request_id": requestId,
            "requestId": requestId
        ]

        let candidates = BackendRoute.phoneVerifyCandidates
        for (index, path) in candidates.enumerated() {
            let request = try makeJSONRequest(pathComponents: path, body: body)
            let (data, response) = try await CMHTTP.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

            guard (200..<300).contains(http.statusCode) else {
                if shouldTryFallback(statusCode: http.statusCode, currentIndex: index, total: candidates.count) {
                    continue
                }
                throw APIError.message(friendlyStatusMessage(statusCode: http.statusCode, data: data, operation: "verify your code"))
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(Self.isoFormatter)
                return try decoder.decode(PhoneVerificationVerifyResponse.self, from: data)
            } catch {
                throw APIError.message("Verification service returned an unexpected response. Please try again.")
            }
        }

        throw APIError.message("Verification service route is unavailable. Please verify backend URL.")
    }

}
