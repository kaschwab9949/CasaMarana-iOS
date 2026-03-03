import Foundation

func normalizeCustomerEmail(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

func isValidCustomerEmail(_ raw: String) -> Bool {
    let email = normalizeCustomerEmail(raw)
    if email.isEmpty {
        return true
    }

    guard email.count <= 254 else { return false }
    let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
    return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

func normalizeCustomerBirthday(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return ""
    }

    let parts = trimmed.split(separator: "-", omittingEmptySubsequences: false)

    if parts.count == 2,
       let month = Int(parts[0]),
       let day = Int(parts[1]),
       isValidMonthDay(month: month, day: day, year: 2000) {
        return String(format: "%02d-%02d", month, day)
    }

    if parts.count == 3,
       parts[0].count == 4,
       let year = Int(parts[0]),
       let month = Int(parts[1]),
       let day = Int(parts[2]),
       (0...9999).contains(year) {
        let validationYear = year == 0 ? 2000 : year
        if isValidMonthDay(month: month, day: day, year: validationYear) {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    return nil
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
