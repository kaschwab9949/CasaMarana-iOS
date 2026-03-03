import Foundation

struct PhoneVerificationStartResponse: Codable {
    /// Opaque id for this verification attempt.
    let requestId: String
}

struct PhoneVerificationVerifyResponse: Codable {
    let verified: Bool
    /// Optional long-lived token proving verification.
    let token: String?
}

final class PhoneVerificationAPI {
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
        let url = BackendRoute.url(for: BackendRoute.phoneStart)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)

        let body: [String: Any] = ["phone": phoneE164]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.message(friendlyStatusMessage(statusCode: http.statusCode, data: data, operation: "send verification code"))
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if contentType.contains("text/html") {
            throw APIError.message("Verification service is unavailable right now. Please try again.")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.isoFormatter)
            return try decoder.decode(PhoneVerificationStartResponse.self, from: data)
        } catch {
            throw APIError.message("Verification service returned an unexpected response. Please try again.")
        }
    }

    func verify(phoneE164: String, code: String, requestId: String) async throws -> PhoneVerificationVerifyResponse {
        let url = BackendRoute.url(for: BackendRoute.phoneVerify)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "phone": phoneE164,
            "code": code,
            "request_id": requestId
        ], options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
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

}
