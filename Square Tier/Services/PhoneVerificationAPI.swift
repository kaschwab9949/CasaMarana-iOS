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
    private func applyAuthHeaders(_ request: inout URLRequest) {
        let key = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            let token = key.lowercased().hasPrefix("bearer ") ? key : "Bearer \(key)"
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
    }

    private static let isoFormatter: DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        d.timeZone = TimeZone(secondsFromGMT: 0)
        return d
    }()

    private static func responsePreview(_ data: Data, limit: Int = 300) -> String {
        let s = String(decoding: data, as: UTF8.self)
        return String(s.prefix(limit))
    }

    func start(phoneE164: String) async throws -> PhoneVerificationStartResponse {
        if AppConfig.backendBaseURL.host?.lowercased().contains("example") == true {
            // For testing UI without a backend, fake a success response after 1s
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return PhoneVerificationStartResponse(requestId: UUID().uuidString)
        }

        let url = AppConfig.backendBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("auth")
            .appendingPathComponent("phone")
            .appendingPathComponent("start")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(&request)

        let body: [String: Any] = ["phone": phoneE164]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if !text.isEmpty {
                throw APIError.message("HTTP \(http.statusCode) from \(url.absoluteString): \(text)")
            }
            throw APIError.message("HTTP \(http.statusCode) from \(url.absoluteString)")
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if contentType.contains("text/html") {
            let preview = Self.responsePreview(data)
            throw APIError.message("Expected JSON but received HTML. Ensure backend is running and not returning an error page. Body: \(preview)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.isoFormatter)
            return try decoder.decode(PhoneVerificationStartResponse.self, from: data)
        } catch {
            let preview = Self.responsePreview(data)
            throw APIError.message("Could not decode phone verification response. Body: \(preview)")
        }
    }

    func verify(phoneE164: String, code: String, requestId: String) async throws -> PhoneVerificationVerifyResponse {
        if AppConfig.backendBaseURL.host?.lowercased().contains("example") == true {
            // Fake verify
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if code == "123456" {
                return PhoneVerificationVerifyResponse(verified: true, token: "fake_token_\(UUID().uuidString)")
            } else {
                throw APIError.message("Invalid code (for testing without backend, use 123456).")
            }
        }

        let url = AppConfig.backendBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("auth")
            .appendingPathComponent("phone")
            .appendingPathComponent("verify")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(&request)

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "phone": phoneE164,
            "code": code,
            "request_id": requestId
        ], options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if !text.isEmpty {
                throw APIError.message("HTTP \(http.statusCode) from \(url.absoluteString): \(text)")
            }
            throw APIError.message("HTTP \(http.statusCode) from \(url.absoluteString)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.isoFormatter)
            return try decoder.decode(PhoneVerificationVerifyResponse.self, from: data)
        } catch {
            let preview = Self.responsePreview(data)
            throw APIError.message("Could not decode phone verification response. Body: \(preview)")
        }
    }

}
