import SwiftUI

// MARK: - App Brand Tokens

/// Canonical brand namespace used across the app.
enum CMBrand {
    static let accent: Color = .mint
    static let background: Color = Color(.systemBackground)
    static let foreground: Color = Color(.label)

    /// Secondary accent for destructive / alert actions.
    static let destructive: Color = .red
}

/// Legacy alias — kept so older references still compile.
typealias Brand = CMBrand
