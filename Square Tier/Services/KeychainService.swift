import Foundation
import Security

enum KeychainService {
    private static let service = "com.casaMarana.app"
    private static let uiTestFallbackPrefix = "cm.uiTest.keychain."

    private static var isUITesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-ui-testing-reset-session")
            || args.contains("-ui-testing-seed-demo-account")
    }

    private static func fallbackKey(for account: String) -> String {
        "\(uiTestFallbackPrefix)\(account)"
    }

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        let add: [String: Any] = query.merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]) { $1 }
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess {
            if isUITesting {
                UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
            }
            return true
        }

        // Simulator UI-test runners occasionally fail keychain writes; keep this scoped to UI tests.
        guard isUITesting else { return false }
        UserDefaults.standard.set(value, forKey: fallbackKey(for: account))
        return true
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }

        guard isUITesting else { return nil }
        return UserDefaults.standard.string(forKey: fallbackKey(for: account))
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
    }
}
