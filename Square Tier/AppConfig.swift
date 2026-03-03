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
    private static let runtimeBackendBaseURLKey = "cm.runtime.backendBaseURL"
    private static let runtimeAuthHeaderModeKey = "cm.runtime.authHeaderMode"
    private static let runtimeAPIKeyAccount = "cm.runtime.apiKey"

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
        return URL(string: trimmed)
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

    public static var runtimeBackendBaseURLOverride: String? {
#if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: runtimeBackendBaseURLKey) else {
            return nil
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : raw
#else
        return nil
#endif
    }

    public static var runtimeAuthHeaderModeOverride: AuthHeaderMode? {
#if DEBUG
        parseAuthHeaderMode(UserDefaults.standard.string(forKey: runtimeAuthHeaderModeKey))
#else
        return nil
#endif
    }

    public static var hasRuntimeAPIKeyOverride: Bool {
#if DEBUG
        normalizedKey(KeychainService.load(account: runtimeAPIKeyAccount)) != nil
#else
        return false
#endif
    }

    public static var hasRuntimeOverrides: Bool {
        runtimeBackendBaseURLOverride != nil || runtimeAuthHeaderModeOverride != nil || hasRuntimeAPIKeyOverride
    }

    // Base URL of your backend.
    // Falls back to production backend if config values are missing.
    public static var backendBaseURL: URL {
        if let runtimeURL = normalizedURL(from: runtimeBackendBaseURLOverride) {
            return runtimeURL
        }
        if let plistURL = normalizedURL(from: plistString("CMBackendBaseURL")) {
            return plistURL
        }
        return defaultBackendBaseURL
    }

    // API key header value for your backend. Must match backend expectation if configured.
    public static var apiKey: String {
#if DEBUG
        if let runtime = normalizedKey(KeychainService.load(account: runtimeAPIKeyAccount)) {
            return runtime
        }
#endif
        return normalizedKey(plistString("CMAPIKey")) ?? ""
    }

    public static var authHeaderMode: AuthHeaderMode {
        if let runtime = runtimeAuthHeaderModeOverride {
            return runtime
        }
        return parseAuthHeaderMode(plistString("CMAPIAuthMode")) ?? .apiKey
    }

    @discardableResult
    public static func saveRuntimeOverrides(
        baseURL: String?,
        apiKey: String?,
        authHeaderMode: AuthHeaderMode
    ) -> Bool {
        if let url = normalizedKey(baseURL) {
            UserDefaults.standard.set(url, forKey: runtimeBackendBaseURLKey)
        } else {
            UserDefaults.standard.removeObject(forKey: runtimeBackendBaseURLKey)
        }

        UserDefaults.standard.set(authHeaderMode.rawValue, forKey: runtimeAuthHeaderModeKey)

        if let key = normalizedKey(apiKey) {
            return KeychainService.save(key, account: runtimeAPIKeyAccount)
        } else {
            KeychainService.delete(account: runtimeAPIKeyAccount)
            return true
        }
    }

    public static func clearRuntimeOverrides() {
        UserDefaults.standard.removeObject(forKey: runtimeBackendBaseURLKey)
        UserDefaults.standard.removeObject(forKey: runtimeAuthHeaderModeKey)
        KeychainService.delete(account: runtimeAPIKeyAccount)
    }

}
