import Foundation

final class SquareMenuAPI {
    private struct AuthAttempt: Hashable {
        let apiKey: String
        let mode: AppConfig.AuthHeaderMode
    }

    private func authAttempts() -> [AuthAttempt] {
        var seen = Set<AuthAttempt>()
        var attempts: [AuthAttempt] = []

        for key in AppConfig.apiKeyCandidates {
            for mode in AppConfig.authHeaderModeCandidates {
                let candidate = AuthAttempt(apiKey: key, mode: mode)
                if seen.insert(candidate).inserted {
                    attempts.append(candidate)
                }
            }
        }

        return attempts
    }

    private func applyAuthHeaders(_ request: inout URLRequest, auth: AuthAttempt) throws {
        guard CMHTTP.applyAuthHeaders(&request, apiKey: auth.apiKey, authHeaderMode: auth.mode) else {
            throw APIError.message("Menu service is not configured. Add an API key in Settings.")
        }
    }

    private func friendlyAPIError(statusCode: Int, data: Data) -> APIError {
        let raw = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerRaw = raw.lowercased()

        if statusCode == 429 {
            return .rateLimited(retryAfter: nil)
        }

        if statusCode == 401 || statusCode == 403 {
            if AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .message("Menu service is not configured. Add your API key and try again.")
            }
            return .message("Menu service rejected this credential. Verify API settings and try again.")
        }

        if statusCode == 404 {
            return .message("Menu route is unavailable. Verify backend URL and deployment.")
        }

        if lowerRaw.contains("<!doctype html") || lowerRaw.contains("<html") {
            return .message("Menu service returned an unexpected response. Verify backend URL and API route.")
        }

        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let fields = ["message", "error", "detail"]
            for field in fields {
                if let value = object[field] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    let looksLikeCode =
                        trimmed.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil
                        || trimmed.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
                    if !trimmed.isEmpty
                        && trimmed.first != "{"
                        && trimmed.first != "["
                        && !(looksLikeCode && (trimmed.contains("_") || trimmed.contains("-"))) {
                        return .message(trimmed)
                    }
                }
            }
        }

        return .badStatus(statusCode)
    }

    func fetchMenu() async throws -> [MenuItem] {
        let authAttempts = authAttempts()
        guard !authAttempts.isEmpty else {
            throw APIError.message("Menu service is not configured. Add an API key in Settings.")
        }

        var lastError: APIError?
        for pathComponents in BackendRoute.menuCandidates {
            let endpoint = BackendRoute.url(for: pathComponents)

            for authAttempt in authAttempts {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "GET"
                request.timeoutInterval = 40
                try applyAuthHeaders(&request, auth: authAttempt)

                let (data, response) = try await CMHTTP.session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.message("No HTTP response")
                }

                if http.statusCode == 401 || http.statusCode == 403 {
                    lastError = friendlyAPIError(statusCode: http.statusCode, data: data)
                    continue
                }

                if http.statusCode == 404 {
                    lastError = friendlyAPIError(statusCode: http.statusCode, data: data)
                    break
                }

                guard (200..<300).contains(http.statusCode) else {
                    throw friendlyAPIError(statusCode: http.statusCode, data: data)
                }

                let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
                if contentType.contains("text/html") {
                    lastError = .message("Menu service returned an unexpected response. Verify backend URL and API route.")
                    continue
                }

                let decoded = parseMenuItems(from: data)
                if !decoded.isEmpty {
                    return decoded
                }

                lastError = .decoding
            }
        }

        if let lastError {
            throw lastError
        }
        throw APIError.message("Menu service is unavailable.")
    }

    private func parseMenuItems(from data: Data) -> [MenuItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return []
        }

        if let array = json as? [[String: Any]] {
            return dedupeAndSort(array.compactMap(parseSimpleItem(from:)))
        }

        if let object = json as? [String: Any] {
            let candidateArrays: [Any?] = [
                object["items"],
                object["menu"],
                object["data"],
                object["results"]
            ]

            for candidate in candidateArrays {
                if let array = candidate as? [[String: Any]] {
                    let items = dedupeAndSort(array.compactMap(parseSimpleItem(from:)))
                    if !items.isEmpty {
                        return items
                    }
                }
            }

            if let catalogObjects = object["objects"] as? [[String: Any]] {
                let catalogItems = dedupeAndSort(parseCatalogObjects(catalogObjects))
                if !catalogItems.isEmpty {
                    return catalogItems
                }
            }
        }

        return []
    }

    private func parseCatalogObjects(_ objects: [[String: Any]]) -> [MenuItem] {
        var categoryByID: [String: String] = [:]
        for object in objects {
            guard let type = object["type"] as? String, type.uppercased() == "CATEGORY" else { continue }
            guard let id = object["id"] as? String else { continue }
            let categoryData = object["category_data"] as? [String: Any]
            let name = (categoryData?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty {
                categoryByID[id] = name
            }
        }

        var parsed: [MenuItem] = []
        for object in objects {
            guard let type = object["type"] as? String, type.uppercased() == "ITEM" else { continue }
            guard let id = object["id"] as? String else { continue }
            guard let itemData = object["item_data"] as? [String: Any] else { continue }

            let name = (itemData["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { continue }

            let description = (itemData["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let categoryID = (itemData["category_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let category = categoryByID[categoryID] ?? "Menu"

            let variations = itemData["variations"] as? [[String: Any]] ?? []
            let prices = variations.compactMap { variation -> Int? in
                guard let variationData = variation["item_variation_data"] as? [String: Any] else { return nil }
                guard let priceMoney = variationData["price_money"] as? [String: Any] else { return nil }
                return priceMoney["amount"] as? Int
            }

            let price = prices.min().map(formatPrice) ?? ""
            let tags = (itemData["ecom_seo_data"] as? [String: Any])?["title"] as? String

            parsed.append(
                MenuItem(
                    id: id,
                    name: name,
                    description: description,
                    price: price,
                    category: category,
                    displayCategory: category,
                    tags: tags.map { [$0] } ?? [category],
                    sectionHint: nil,
                    sectionRank: nil,
                    categoryRank: nil,
                    itemRank: nil
                )
            )
        }
        return parsed
    }

    private func parseSimpleItem(from object: [String: Any]) -> MenuItem? {
        let id = firstString(in: object, keys: ["id", "item_id", "itemId", "catalog_object_id"]) ?? UUID().uuidString
        guard let name = firstString(in: object, keys: ["name", "title", "item_name", "itemName"]),
              !name.isEmpty else {
            return nil
        }

        let description = firstString(in: object, keys: ["description", "details", "subtitle"]) ?? ""
        let category = firstString(in: object, keys: ["category", "category_name", "group", "section"]) ?? "Menu"
        let displayCategory = firstString(in: object, keys: ["displayCategory", "display_category"])
        let tags = (object["tags"] as? [String]) ?? [category]
        let sectionHint = firstString(in: object, keys: ["sectionHint", "section_hint", "section"])
        let sectionRank = firstInt(in: object, keys: ["sectionRank", "section_rank"])
        let categoryRank = firstInt(in: object, keys: ["categoryRank", "category_rank"])
        let itemRank = firstInt(in: object, keys: ["itemRank", "item_rank"])

        let priceString: String
        if let directPrice = firstString(in: object, keys: ["price", "price_display", "formatted_price"]) {
            priceString = directPrice
        } else if let amount = firstInt(in: object, keys: ["price_cents", "priceCents", "amount"]) {
            priceString = formatPrice(amount)
        } else if let priceMoney = object["price_money"] as? [String: Any], let amount = priceMoney["amount"] as? Int {
            priceString = formatPrice(amount)
        } else {
            priceString = ""
        }

        return MenuItem(
            id: id,
            name: name,
            description: description,
            price: priceString,
            category: category,
            displayCategory: displayCategory,
            tags: tags,
            sectionHint: sectionHint,
            sectionRank: sectionRank,
            categoryRank: categoryRank,
            itemRank: itemRank
        )
    }

    private func dedupeAndSort(_ items: [MenuItem]) -> [MenuItem] {
        var seen = Set<String>()
        let unique = items.filter { item in
            seen.insert(item.id).inserted
        }

        return unique.sorted {
            let leftSectionRank = $0.sectionRank ?? Int.max
            let rightSectionRank = $1.sectionRank ?? Int.max
            if leftSectionRank != rightSectionRank {
                return leftSectionRank < rightSectionRank
            }

            let leftCategoryRank = $0.categoryRank ?? Int.max
            let rightCategoryRank = $1.categoryRank ?? Int.max
            if leftCategoryRank != rightCategoryRank {
                return leftCategoryRank < rightCategoryRank
            }

            let leftItemRank = $0.itemRank ?? Int.max
            let rightItemRank = $1.itemRank ?? Int.max
            if leftItemRank != rightItemRank {
                return leftItemRank < rightItemRank
            }

            if $0.effectiveCategory == $1.effectiveCategory {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.effectiveCategory.localizedCaseInsensitiveCompare($1.effectiveCategory) == .orderedAscending
        }
    }

    private func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func firstInt(in object: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = object[key] as? Int {
                return value
            }
            if let value = object[key] as? Double {
                return Int(value)
            }
            if let value = object[key] as? String, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    private func formatPrice(_ cents: Int) -> String {
        let dollars = Decimal(cents) / Decimal(100)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: dollars as NSDecimalNumber) ?? "$0.00"
    }
}
