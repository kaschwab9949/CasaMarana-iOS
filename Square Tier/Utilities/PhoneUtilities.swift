import Foundation

/// Normalizes a US phone number string to E.164 format (+1XXXXXXXXXX).
/// Accepts formats like: "5205551234", "(520) 555-1234", "+15205551234", "1-520-555-1234".
/// Returns `nil` if the input cannot be interpreted as a valid 10-digit US number.
func normalizePhoneE164(_ raw: String) -> String? {
    let digits = raw.filter { $0.isNumber }

    switch digits.count {
    case 10:
        return "+1\(digits)"
    case 11 where digits.hasPrefix("1"):
        return "+\(digits)"
    default:
        return nil
    }
}
