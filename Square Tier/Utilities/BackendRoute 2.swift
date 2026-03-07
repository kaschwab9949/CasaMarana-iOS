import Foundation

enum BackendRoute {
    static let loyaltyStatus = ["api", "loyalty", "status"]
    static let loyaltyEnroll = ["api", "loyalty", "enroll"]
    static let loyaltyAccountsSearch = ["api", "loyalty", "accounts", "search"]
    static let loyaltyPass = ["api", "loyalty", "pass"]

    static let phoneStart = ["api", "auth", "phone", "start"]
    static let phoneVerify = ["api", "auth", "phone", "verify"]
    static let phoneStartLegacy = ["api", "phone", "start"]
    static let phoneVerifyLegacy = ["api", "phone", "verify"]

    static let snakeLeaderboard = ["api", "snake", "leaderboard"]
    static let snakeScore = ["api", "snake", "score"]

    static let health = ["api", "health"]

    static let smartCheckInCanonical = ["api", "location", "sample"]
    static let smartCheckInAlias = ["api", "loyalty", "location"]

    static let accountDeleteCanonical = ["api", "account", "delete"]
    static let accountDeleteAliasAuthAccount = ["api", "auth", "account", "delete"]
    static let accountDeleteAliasLegacy = ["api", "auth", "delete-account"]

    static let menuCanonical = ["api", "menu"]
    static let menuAliasItems = ["api", "menu", "items"]
    static let menuAliasCatalog = ["api", "catalog", "menu"]

    static var smartCheckInCandidates: [[String]] {
        [smartCheckInCanonical, smartCheckInAlias]
    }

    static var accountDeleteCandidates: [[String]] {
        [accountDeleteCanonical, accountDeleteAliasAuthAccount, accountDeleteAliasLegacy]
    }

    static var menuCandidates: [[String]] {
        [menuCanonical, menuAliasItems, menuAliasCatalog]
    }

    static var phoneStartCandidates: [[String]] {
        [phoneStart, phoneStartLegacy]
    }

    static var phoneVerifyCandidates: [[String]] {
        [phoneVerify, phoneVerifyLegacy]
    }

    static func url(for pathComponents: [String], baseURL: URL = AppConfig.backendBaseURL) -> URL {
        pathComponents.reduce(baseURL) { partialResult, component in
            partialResult.appendingPathComponent(component)
        }
    }
}
