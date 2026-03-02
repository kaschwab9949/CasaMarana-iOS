import Foundation

struct RewardTier: Codable, Identifiable {
    let id: String
    let name: String
    let points: Int
}

struct LoyaltyStatusResponse: Codable {
    let enrolled: Bool
    let points: Int
    let rewardTiers: [RewardTier]
}

final class LoyaltyAPI {
    private func applyAuthHeaders(_ request: inout URLRequest) {
        let key = AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            let token = key.lowercased().hasPrefix("bearer ") ? key : "Bearer \(key)"
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
    }

    /// Fetch the loyalty status for a verified phone number.
    /// Also available as `checkStatus(phoneE164:)` for legacy callers.
    func fetchStatus(phoneE164: String) async throws -> LoyaltyStatusResponse {
        try await checkStatus(phoneE164: phoneE164)
    }

    func checkStatus(phoneE164: String) async throws -> LoyaltyStatusResponse {
        if AppConfig.backendBaseURL.host?.lowercased().contains("example") == true {
            throw APIError.message("Loyalty backend is not configured (backendBaseURL is example.com).")
        }

        let url = AppConfig.backendBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("loyalty")
            .appendingPathComponent("status")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(&request)

        let body: [String: Any] = ["phone": phoneE164]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                throw APIError.message(text)
            }
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(LoyaltyStatusResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func fetchWalletPass(
        phoneE164: String,
        serial: String,
        memberName: String,
        memberId: String,
        tierName: String,
        points: Int
    ) async throws -> Data {
        let endpoint = AppConfig.backendBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("loyalty")
            .appendingPathComponent("pass")

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "phone", value: phoneE164),
            URLQueryItem(name: "serialNumber", value: serial),
            URLQueryItem(name: "memberName", value: memberName),
            URLQueryItem(name: "memberId", value: memberId),
            URLQueryItem(name: "tierName", value: tierName),
            URLQueryItem(name: "points", value: String(points))
        ]
        
        guard let url = comps.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")
        applyAuthHeaders(&request)

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                throw APIError.message(text)
            }
            throw APIError.badStatus(http.statusCode)
        }

        return data
    }

    func postLocationSample(
        phoneE164: String,
        lat: Double,
        lon: Double,
        accuracy: Double,
        timestamp: TimeInterval
    ) async throws {
        if AppConfig.backendBaseURL.host?.lowercased().contains("example") == true {
            throw APIError.message("Location backend is not configured (backendBaseURL is example.com).")
        }

        let url = AppConfig.backendBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("loyalty")
            .appendingPathComponent("location")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(&request)

        let body: [String: Any] = [
            "phone": phoneE164,
            "lat": lat,
            "lon": lon,
            "accuracy": accuracy,
            "timestamp": timestamp
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (_, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else { throw APIError.badStatus(http.statusCode) }
    }
}
