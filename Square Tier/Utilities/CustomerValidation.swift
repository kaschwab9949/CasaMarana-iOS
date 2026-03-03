import Foundation

func normalizeCustomerEmail(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

func isValidCustomerEmailOptional(_ raw: String) -> Bool {
    let email = normalizeCustomerEmail(raw)
    if email.isEmpty {
        return true
    }

    guard email.count <= 254 else { return false }
    let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
    return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

func isValidCustomerEmailRequired(_ raw: String) -> Bool {
    let email = normalizeCustomerEmail(raw)
    guard !email.isEmpty else { return false }
    return isValidCustomerEmailOptional(email)
}

func isValidCustomerEmail(_ raw: String) -> Bool {
    isValidCustomerEmailOptional(raw)
}

func normalizeCustomerBirthday(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return ""
    }

    let cleaned = trimmed
        .replacingOccurrences(of: "-", with: "/")
        .replacingOccurrences(of: ".", with: "/")

    let parts = cleaned.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    guard
        let first = Int(parts[0]),
        let second = Int(parts[1]),
        let third = Int(parts[2])
    else {
        return nil
    }

    let month: Int
    let day: Int
    let year: Int

    if parts[0].count == 4 {
        // Backward compatibility for legacy YYYY-MM-DD values.
        year = first
        month = second
        day = third
    } else {
        month = first
        day = second

        if parts[2].count == 4 {
            year = third
        } else if parts[2].count <= 2, (0...99).contains(third) {
            year = fullYearFromTwoDigit(third)
        } else {
            return nil
        }
    }

    guard (1...9999).contains(year) else { return nil }
    let validationYear = year == 0 ? 2000 : year
    guard isValidMonthDay(month: month, day: day, year: validationYear) else { return nil }

    return String(format: "%02d/%02d/%02d", month, day, year % 100)
}

func normalizeCustomerBirthdayRequired(_ raw: String) -> String? {
    guard let normalized = normalizeCustomerBirthday(raw) else { return nil }
    let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func isValidMonthDay(month: Int, day: Int, year: Int) -> Bool {
    guard (1...12).contains(month), (1...31).contains(day) else { return false }
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.year = year
    components.month = month
    components.day = day
    return components.date != nil
}

private func fullYearFromTwoDigit(_ year: Int, referenceDate: Date = Date()) -> Int {
    let clamped = max(0, min(99, year))
    let calendar = Calendar(identifier: .gregorian)
    let currentYear = calendar.component(.year, from: referenceDate)
    let currentCentury = (currentYear / 100) * 100
    let currentTwoDigit = currentYear % 100

    if clamped <= currentTwoDigit {
        return currentCentury + clamped
    }
    return (currentCentury - 100) + clamped
}
