import Foundation

enum MenuSection: String, CaseIterable, Identifiable {
    case food
    case drinks
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .other: return "Other"
        }
    }
}

enum MenuCategoryMapping {
    // Business-priority category mapping. Exact category matches win first.
    private static let explicitCategoryMap: [String: MenuSection] = [
        "food": .food,
        "food menu": .food,
        "starters": .food,
        "appetizers": .food,
        "small plates": .food,
        "salads": .food,
        "soup": .food,
        "sandwiches": .food,
        "burgers": .food,
        "pizza": .food,
        "entrees": .food,
        "dessert": .food,
        "desserts": .food,
        "sides": .food,
        "kids": .food,

        "mixed drinks": .drinks,
        "cocktails": .drinks,
        "beer": .drinks,
        "draft beer": .drinks,
        "package": .drinks,
        "wine": .drinks,
        "draft wine": .drinks,
        "spirits": .drinks,
        "tequila/mezcal": .drinks,
        "vodka": .drinks,
        "rum": .drinks,
        "gin": .drinks,
        "whiskey/scotch": .drinks,
        "brandy/cognac": .drinks,
        "cordials": .drinks,
        "non alch": .drinks,
        "non-alch": .drinks,
        "non alcoholic": .drinks
    ]

    private static let foodKeywords = [
        "food", "menu", "pizza", "burger", "fries", "salad", "soup",
        "appetizer", "entree", "dessert", "sandwich", "wings", "nachos",
        "tacos", "pasta", "steak", "chicken", "shrimp", "plate", "bowl"
    ]

    private static let drinkKeywords = [
        "drink", "cocktail", "beer", "wine", "spirits", "liquor", "vodka",
        "whiskey", "scotch", "bourbon", "tequila", "mezcal", "gin", "rum",
        "brandy", "cordial", "non alch", "non-alch", "coffee", "soda", "draft"
    ]

    private static let foodCategoryPriority = [
        "Starters", "Appetizers", "Salads", "Sandwiches", "Pizza", "Entrees", "Desserts", "Sides"
    ]

    private static let drinkCategoryPriority = [
        "Mixed Drinks", "Cocktails", "Draft Beer", "Package", "Beer", "Wine", "Draft Wine",
        "Whiskey/Scotch", "Tequila/Mezcal", "Vodka", "Gin", "Rum", "Brandy/Cognac", "Cordials", "Non Alch"
    ]

    static func classify(_ item: MenuItem) -> MenuSection {
        if let sectionHint = item.sectionHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            switch sectionHint {
            case "food":
                return .food
            case "drink", "drinks":
                return .drinks
            case "other":
                return .other
            default:
                break
            }
        }

        let normalizedCategory = normalize(item.category)
        if let explicit = explicitCategoryMap[normalizedCategory] {
            return explicit
        }

        let categoryAndName = "\(item.category) \(item.name)"
        if containsKeyword(categoryAndName, from: foodKeywords) {
            return .food
        }
        if containsKeyword(categoryAndName, from: drinkKeywords) {
            return .drinks
        }

        if containsKeyword(item.tags.joined(separator: " "), from: foodKeywords) {
            return .food
        }
        if containsKeyword(item.tags.joined(separator: " "), from: drinkKeywords) {
            return .drinks
        }

        return .other
    }

    static func orderedCategories(in section: MenuSection, items: [MenuItem]) -> [String] {
        let grouped = Set(items.map { $0.category })
        let sourcePriority: [String]
        switch section {
        case .food:
            sourcePriority = foodCategoryPriority
        case .drinks:
            sourcePriority = drinkCategoryPriority
        case .other:
            sourcePriority = []
        }

        var ordered: [String] = []
        for category in sourcePriority where grouped.contains(category) {
            ordered.append(category)
        }

        let remaining = grouped
            .subtracting(ordered)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func containsKeyword(_ value: String, from keywords: [String]) -> Bool {
        let haystack = normalize(value)
        guard !haystack.isEmpty else { return false }
        return keywords.contains { haystack.contains($0) }
    }
}
