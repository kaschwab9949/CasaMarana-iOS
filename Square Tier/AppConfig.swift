import Foundation

// Central app configuration used by networking and other services.
// Values are loaded from Info.plist keys injected by build settings.
// Required keys:
// - CMBackendBaseURL
// - CMAPIKey
public enum AppConfig {
    private static let missingBackendURLFallback = URL(string: "https://example.com")!

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

    // Base URL of your backend.
    // Falls back to example.com so API layers emit actionable "backend not configured" errors.
    public static let backendBaseURL: URL = {
        guard let raw = plistString("CMBackendBaseURL"),
              let url = URL(string: raw) else {
            return missingBackendURLFallback
        }
        return url
    }()

    // API key header value for your backend. Must match backend expectation if configured.
    public static let apiKey: String = plistString("CMAPIKey") ?? ""
}
