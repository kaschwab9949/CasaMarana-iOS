import Foundation

// Central app configuration used by networking and other services.
// Values are loaded from Info.plist keys injected by build settings.
// Required keys:
// - CMBackendBaseURL
// - CMAPIKey
public enum AppConfig {
    public enum AuthHeaderMode: String, CaseIterable {
        case apiKey = "x-api-key"
        case bearer = "bearer"
    }

    private static let defaultBackendBaseURL = URL(string: "https://casa-marana-backend.vercel.app")!

    private static func plistString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Undefined build setting placeholders can leak through as "$(KEY)" strings.
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") {
            return nil
        }

        return trimmed
    }

    private static func normalizedURL(from raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        guard let url = URL(string: trimmed) else { return nil }

        // Reject malformed values (for example "https:" from xcconfig comment parsing).
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" {
            guard let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
                return nil
            }
        }

        return url
    }

    private static func normalizedKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }

    private static func parseAuthHeaderMode(_ raw: String?) -> AuthHeaderMode? {
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "bearer", "authorization", "authorization-bearer", "token":
            return .bearer
        case "x-api-key", "api-key", "api_key", "apikey", "key":
            return .apiKey
        default:
            return nil
        }
    }

    // Base URL of your backend.
    // Falls back to production backend if config values are missing.
    public static var backendBaseURL: URL {
        if let plistURL = normalizedURL(from: plistString("CMBackendBaseURL")) {
            return plistURL
        }
        return defaultBackendBaseURL
    }

    // API key header value for your backend. Must match backend expectation if configured.
    public static var apiKey: String {
        return bundledAPIKey
    }

    public static var bundledAPIKey: String {
        normalizedKey(plistString("CMAPIKey")) ?? ""
    }

    public static var apiKeyCandidates: [String] {
        var seen = Set<String>()
        var candidates: [String] = []
        let rawCandidates: [String] = [apiKey, bundledAPIKey]
        for raw in rawCandidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                candidates.append(trimmed)
            }
        }
        return candidates
    }

    public static var authHeaderMode: AuthHeaderMode {
        return parseAuthHeaderMode(plistString("CMAPIAuthMode")) ?? .apiKey
    }

    public static var authHeaderModeCandidates: [AuthHeaderMode] {
        var modes: [AuthHeaderMode] = [authHeaderMode]
        for mode in AuthHeaderMode.allCases where !modes.contains(mode) {
            modes.append(mode)
        }
        return modes
    }

}
