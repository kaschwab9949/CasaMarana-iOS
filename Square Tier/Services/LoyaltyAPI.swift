import Foundation

struct RewardTier: Decodable, Identifiable {
    let id: String
    let name: String
    let points: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case label
        case tier
        case points
        case pointsRequired = "points_required"
        case requiredPoints = "required_points"
        case pointsCost = "points_cost"
        case minimumPoints = "minimum_points"
        case minPoints = "min_points"
        case threshold
    }

    init(id: String, name: String, points: Int) {
        self.id = id
        self.name = name
        self.points = points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeInt(for key: CodingKeys) -> Int? {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }

        let nameFromName = try? container.decodeIfPresent(String.self, forKey: .name)
        let nameFromTitle = try? container.decodeIfPresent(String.self, forKey: .title)
        let nameFromLabel = try? container.decodeIfPresent(String.self, forKey: .label)
        let nameFromTier = try? container.decodeIfPresent(String.self, forKey: .tier)
        let parsedName = nameFromName ?? nameFromTitle ?? nameFromLabel ?? nameFromTier ?? "Reward"

        let parsedPoints =
            decodeInt(for: .points)
            ?? decodeInt(for: .pointsRequired)
            ?? decodeInt(for: .requiredPoints)
            ?? decodeInt(for: .pointsCost)
            ?? decodeInt(for: .minimumPoints)
            ?? decodeInt(for: .minPoints)
            ?? decodeInt(for: .threshold)
            ?? 0

        let explicitID = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? nil

        let parsedID: String
        if let explicitID, !explicitID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            parsedID = explicitID
        } else {
            parsedID = "\(parsedName)-\(parsedPoints)"
        }

        self.id = parsedID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        self.name = parsedName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        self.points = max(0, parsedPoints)
    }
}

struct CustomerSegmentSummary: Decodable, Identifiable {
    let id: String
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case segmentID = "segment_id"
        case segmentIDCamel = "segmentId"
        case displayName = "display_name"
    }

    init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawID =
            (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .segmentID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .segmentIDCamel))
            ?? ""
        id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawName =
            (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? nil
        let trimmedName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = trimmedName.isEmpty ? nil : trimmedName
    }
}

struct CustomerGroupSummary: Decodable, Identifiable {
    let id: String
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case groupID = "group_id"
        case groupIDCamel = "groupId"
        case displayName = "display_name"
    }

    init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawID =
            (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .groupID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .groupIDCamel))
            ?? ""
        id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawName =
            (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? nil
        let trimmedName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = trimmedName.isEmpty ? nil : trimmedName
    }
}

struct LoyaltyStatusResponse: Decodable {
    let enrolled: Bool
    let points: Int
    let rewardTiers: [RewardTier]
    let tierName: String?
    let availableRewards: [String]
    let phoneNumber: String?
    let membershipStartDate: String?
    let customerID: String?
    let segmentIDs: [String]
    let customerSegments: [CustomerSegmentSummary]
    let groupIDs: [String]
    let customerGroups: [CustomerGroupSummary]

    private enum CodingKeys: String, CodingKey {
        case enrolled
        case isEnrolled = "is_enrolled"
        case points
        case pointsBalance = "points_balance"
        case pointBalance = "point_balance"
        case balance
        case rewardTiers
        case rewardTiersSnake = "reward_tiers"
        case tiers
        case tierName
        case tier
        case loyaltyTier = "loyalty_tier"
        case availableRewards = "available_rewards"
        case rewards
        case phoneNumber
        case phoneNumberSnake = "phone_number"
        case membershipStartDate
        case membershipStartDateSnake = "membership_start_date"
        case memberSince = "member_since"
        case enrolledAt = "enrolled_at"
        case createdAt = "created_at"
        case customerID = "customer_id"
        case customerIDCamel = "customerId"
        case segmentIDs = "segment_ids"
        case segmentIDsCamel = "segmentIds"
        case customerSegmentIDs = "customer_segment_ids"
        case customerSegmentIDsCamel = "customerSegmentIds"
        case segments
        case customerSegments = "customer_segments"
        case smartGroups = "smart_groups"
        case groupIDs = "group_ids"
        case groupIDsCamel = "groupIds"
        case customerGroupIDs = "customer_group_ids"
        case customerGroupIDsCamel = "customerGroupIds"
        case groups
        case customerGroups = "customer_groups"
        case manualGroups = "manual_groups"
    }

    init(
        enrolled: Bool,
        points: Int = 0,
        rewardTiers: [RewardTier] = [],
        tierName: String? = nil,
        availableRewards: [String] = [],
        phoneNumber: String? = nil,
        membershipStartDate: String? = nil,
        customerID: String? = nil,
        segmentIDs: [String] = [],
        customerSegments: [CustomerSegmentSummary] = [],
        groupIDs: [String] = [],
        customerGroups: [CustomerGroupSummary] = []
    ) {
        self.enrolled = enrolled
        self.points = points
        self.rewardTiers = rewardTiers
        self.tierName = tierName
        self.availableRewards = availableRewards
        self.phoneNumber = phoneNumber
        self.membershipStartDate = membershipStartDate
        self.customerID = customerID
        self.segmentIDs = segmentIDs
        self.customerSegments = customerSegments
        self.groupIDs = groupIDs
        self.customerGroups = customerGroups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeInt(for key: CodingKeys) -> Int? {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }

        func decodeBool(for key: CodingKeys) -> Bool? {
            if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "1", "true", "yes", "y", "enrolled":
                    return true
                case "0", "false", "no", "n", "unenrolled":
                    return false
                default:
                    return nil
                }
            }
            return nil
        }

        func decodeTrimmedString(for key: CodingKeys) -> String? {
            guard let value = try? container.decodeIfPresent(String.self, forKey: key) else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func decodeTrimmedStringArray(for key: CodingKeys) -> [String]? {
            if let values = try? container.decodeIfPresent([String].self, forKey: key) {
                let cleaned = values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return cleaned
            }

            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                let parts = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return parts.isEmpty ? nil : parts
            }

            return nil
        }

        func uniqueNonEmptyStrings(_ values: [String]) -> [String] {
            var seen = Set<String>()
            var result: [String] = []
            for value in values {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if seen.insert(trimmed).inserted {
                    result.append(trimmed)
                }
            }
            return result
        }

        enrolled = decodeBool(for: .enrolled) ?? decodeBool(for: .isEnrolled) ?? false
        points =
            decodeInt(for: .points)
            ?? decodeInt(for: .pointsBalance)
            ?? decodeInt(for: .pointBalance)
            ?? decodeInt(for: .balance)
            ?? 0

        rewardTiers =
            try container.decodeIfPresent([RewardTier].self, forKey: .rewardTiers)
            ?? container.decodeIfPresent([RewardTier].self, forKey: .rewardTiersSnake)
            ?? container.decodeIfPresent([RewardTier].self, forKey: .tiers)
            ?? container.decodeIfPresent([RewardTier].self, forKey: .availableRewards)
            ?? container.decodeIfPresent([RewardTier].self, forKey: .rewards)
            ?? []

        let tierFromTierName = try? container.decodeIfPresent(String.self, forKey: .tierName)
        let tierFromTier = try? container.decodeIfPresent(String.self, forKey: .tier)
        let tierFromLoyaltyTier = try? container.decodeIfPresent(String.self, forKey: .loyaltyTier)
        tierName = tierFromTierName ?? tierFromTier ?? tierFromLoyaltyTier

        let rewardsFromAvailableStrings = try? container.decodeIfPresent([String].self, forKey: .availableRewards)
        let rewardsFromRewardsStrings = try? container.decodeIfPresent([String].self, forKey: .rewards)
        let rewardsFromAvailableObjects = try? container.decodeIfPresent([RewardTier].self, forKey: .availableRewards)
        let rewardsFromRewardsObjects = try? container.decodeIfPresent([RewardTier].self, forKey: .rewards)
        availableRewards =
            rewardsFromAvailableStrings
            ?? rewardsFromRewardsStrings
            ?? rewardsFromAvailableObjects?.map(\.name)
            ?? rewardsFromRewardsObjects?.map(\.name)
            ?? []

        phoneNumber = decodeTrimmedString(for: .phoneNumber)
            ?? decodeTrimmedString(for: .phoneNumberSnake)

        membershipStartDate = decodeTrimmedString(for: .membershipStartDate)
            ?? decodeTrimmedString(for: .membershipStartDateSnake)
            ?? decodeTrimmedString(for: .memberSince)
            ?? decodeTrimmedString(for: .enrolledAt)
            ?? decodeTrimmedString(for: .createdAt)

        customerID = decodeTrimmedString(for: .customerID)
            ?? decodeTrimmedString(for: .customerIDCamel)

        let segmentObjects =
            (try? container.decodeIfPresent([CustomerSegmentSummary].self, forKey: .segments))
            ?? (try? container.decodeIfPresent([CustomerSegmentSummary].self, forKey: .customerSegments))
            ?? (try? container.decodeIfPresent([CustomerSegmentSummary].self, forKey: .smartGroups))
            ?? []

        let segmentIDsList = decodeTrimmedStringArray(for: .segmentIDs) ?? []
        let segmentIDsCamelList = decodeTrimmedStringArray(for: .segmentIDsCamel) ?? []
        let customerSegmentIDsList = decodeTrimmedStringArray(for: .customerSegmentIDs) ?? []
        let customerSegmentIDsCamelList = decodeTrimmedStringArray(for: .customerSegmentIDsCamel) ?? []
        let segmentIDsFromObjects = segmentObjects.map(\.id)

        let segmentIDsFromArrays =
            segmentIDsList
            + segmentIDsCamelList
            + customerSegmentIDsList
            + customerSegmentIDsCamelList
            + segmentIDsFromObjects

        segmentIDs = uniqueNonEmptyStrings(segmentIDsFromArrays)

        var seenSegmentIDs = Set<String>()
        var normalizedSegments: [CustomerSegmentSummary] = []
        for segment in segmentObjects {
            let normalizedID = segment.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty else { continue }
            guard seenSegmentIDs.insert(normalizedID).inserted else { continue }
            normalizedSegments.append(CustomerSegmentSummary(id: normalizedID, name: segment.name))
        }
        customerSegments = normalizedSegments

        let groupObjects =
            (try? container.decodeIfPresent([CustomerGroupSummary].self, forKey: .groups))
            ?? (try? container.decodeIfPresent([CustomerGroupSummary].self, forKey: .customerGroups))
            ?? (try? container.decodeIfPresent([CustomerGroupSummary].self, forKey: .manualGroups))
            ?? []

        let groupIDsList = decodeTrimmedStringArray(for: .groupIDs) ?? []
        let groupIDsCamelList = decodeTrimmedStringArray(for: .groupIDsCamel) ?? []
        let customerGroupIDsList = decodeTrimmedStringArray(for: .customerGroupIDs) ?? []
        let customerGroupIDsCamelList = decodeTrimmedStringArray(for: .customerGroupIDsCamel) ?? []
        let groupIDsFromObjects = groupObjects.map(\.id)

        let groupIDsFromArrays =
            groupIDsList
            + groupIDsCamelList
            + customerGroupIDsList
            + customerGroupIDsCamelList
            + groupIDsFromObjects

        groupIDs = uniqueNonEmptyStrings(groupIDsFromArrays)

        var seenGroupIDs = Set<String>()
        var normalizedGroups: [CustomerGroupSummary] = []
        for group in groupObjects {
            let normalizedID = group.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty else { continue }
            guard seenGroupIDs.insert(normalizedID).inserted else { continue }
            normalizedGroups.append(CustomerGroupSummary(id: normalizedID, name: group.name))
        }
        customerGroups = normalizedGroups
    }
}

struct LoyaltyAccountSummary: Decodable, Identifiable {
    let id: String
    let phoneNumber: String?
    let customerID: String?
    let programID: String?
    let balance: Int
    let lifetimePoints: Int
    let createdAt: String?
    let updatedAt: String?
    let enrolledAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber
        case phoneNumberSnake = "phone_number"
        case customerID = "customer_id"
        case customerIDCamel = "customerId"
        case programID = "program_id"
        case programIDCamel = "programId"
        case balance
        case lifetimePoints = "lifetime_points"
        case lifetimePointsCamel = "lifetimePoints"
        case createdAt = "created_at"
        case createdAtCamel = "createdAt"
        case updatedAt = "updated_at"
        case updatedAtCamel = "updatedAt"
        case enrolledAt = "enrolled_at"
        case enrolledAtCamel = "enrolledAt"
        case mapping
    }

    private enum MappingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case phoneNumberCamel = "phoneNumber"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeInt(for key: CodingKeys) -> Int? {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }

        let rawID = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
        id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)

        let phoneFromTop = (try? container.decodeIfPresent(String.self, forKey: .phoneNumber)) ?? nil
        let phoneFromTopSnake = (try? container.decodeIfPresent(String.self, forKey: .phoneNumberSnake)) ?? nil
        var phoneFromMapping: String? = nil
        if let mapping = try? container.nestedContainer(keyedBy: MappingKeys.self, forKey: .mapping) {
            phoneFromMapping =
                (try? mapping.decodeIfPresent(String.self, forKey: .phoneNumber))
                ?? (try? mapping.decodeIfPresent(String.self, forKey: .phoneNumberCamel))
                ?? nil
        }
        phoneNumber =
            phoneFromTop?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? phoneFromTopSnake?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? phoneFromMapping?.trimmingCharacters(in: .whitespacesAndNewlines)

        customerID =
            ((try? container.decodeIfPresent(String.self, forKey: .customerID)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .customerIDCamel)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)

        programID =
            ((try? container.decodeIfPresent(String.self, forKey: .programID)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .programIDCamel)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)

        balance = decodeInt(for: .balance) ?? 0
        lifetimePoints = decodeInt(for: .lifetimePoints) ?? decodeInt(for: .lifetimePointsCamel) ?? 0

        createdAt =
            ((try? container.decodeIfPresent(String.self, forKey: .createdAt)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .createdAtCamel)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)

        updatedAt =
            ((try? container.decodeIfPresent(String.self, forKey: .updatedAt)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .updatedAtCamel)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)

        enrolledAt =
            ((try? container.decodeIfPresent(String.self, forKey: .enrolledAt)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ((try? container.decodeIfPresent(String.self, forKey: .enrolledAtCamel)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LoyaltyEnrollResponse: Decodable {
    let enrolled: Bool
    let created: Bool
    let account: LoyaltyAccountSummary?

    private enum CodingKeys: String, CodingKey {
        case enrolled
        case created
        case account
        case loyaltyAccount = "loyalty_account"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enrolled = (try? container.decodeIfPresent(Bool.self, forKey: .enrolled)) ?? false
        created = (try? container.decodeIfPresent(Bool.self, forKey: .created)) ?? false
        account =
            try? container.decodeIfPresent(LoyaltyAccountSummary.self, forKey: .account)
            ?? container.decodeIfPresent(LoyaltyAccountSummary.self, forKey: .loyaltyAccount)
    }
}

private struct LoyaltyAccountsSearchResponse: Decodable {
    let accounts: [LoyaltyAccountSummary]
}

final class LoyaltyAPI {
    private func applyAuthHeaders(_ request: inout URLRequest, serviceName: String = "Rewards") throws {
        guard CMHTTP.applyAuthHeaders(&request) else {
            throw APIError.message("\(serviceName) service is not configured. Add an API key in Settings.")
        }
    }

    private func retryAfterSeconds(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let value = response?.value(forHTTPHeaderField: "Retry-After") else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = TimeInterval(trimmed), seconds > 0 else { return nil }
        return seconds
    }

    private func friendlyAPIError(
        statusCode: Int,
        data: Data,
        response: HTTPURLResponse?
    ) -> APIError {
        let raw = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerRaw = raw.lowercased()
        let defaultRateLimitDelay: TimeInterval = 60

        var retryAfter = retryAfterSeconds(from: response)
        if statusCode == 429 {
            return .rateLimited(retryAfter: retryAfter ?? defaultRateLimitDelay)
        }
        if statusCode == 401 || statusCode == 403 {
            if AppConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .message("Rewards service is not configured. Add your API key and try again.")
            }
            return .message("Rewards service rejected this credential. Verify API key settings and try again.")
        }
        if statusCode == 404 {
            return .message("Rewards service route is unavailable. Verify the backend URL and deployment.")
        }
        if lowerRaw.contains("<!doctype html") || lowerRaw.contains("<html") {
            return .message("Rewards service returned an unexpected response. Verify backend URL and API route.")
        }

        var messageCandidates: [String] = []
        var hasRateLimitSignal = false

        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let retry = object["retry_after"] as? Int, retry > 0 {
                retryAfter = TimeInterval(retry)
            } else if let retry = object["retry_after"] as? Double, retry > 0 {
                retryAfter = retry
            }

            if let msg = object["message"] as? String {
                messageCandidates.append(msg)
            }
            if let err = object["error"] as? String {
                messageCandidates.append(err)
            }
            if let detail = object["detail"] as? String {
                messageCandidates.append(detail)
            }
            if let detailsText = object["details"] as? String {
                messageCandidates.append(detailsText)

                if let detailsData = detailsText.data(using: .utf8),
                   let detailsObj = try? JSONSerialization.jsonObject(with: detailsData, options: []) as? [String: Any],
                   let errors = detailsObj["errors"] as? [[String: Any]] {
                    for item in errors {
                        if let code = item["code"] as? String { messageCandidates.append(code) }
                        if let category = item["category"] as? String { messageCandidates.append(category) }
                        if let detail = item["detail"] as? String { messageCandidates.append(detail) }
                    }
                }
            }

            if let detailsObj = object["details"] as? [String: Any],
               let errors = detailsObj["errors"] as? [[String: Any]] {
                for item in errors {
                    if let code = item["code"] as? String { messageCandidates.append(code) }
                    if let category = item["category"] as? String { messageCandidates.append(category) }
                    if let detail = item["detail"] as? String { messageCandidates.append(detail) }
                }
            }
        }

        let combinedSignals = messageCandidates.joined(separator: " ").lowercased()
        hasRateLimitSignal =
            combinedSignals.contains("rate_limited")
            || combinedSignals.contains("rate limit")
            || combinedSignals.contains("exceeded the number of requests")
            || lowerRaw.contains("rate_limited")
            || lowerRaw.contains("rate limit")
            || lowerRaw.contains("exceeded the number of requests")

        if hasRateLimitSignal {
            return .rateLimited(retryAfter: retryAfter ?? defaultRateLimitDelay)
        }

        let firstReadable = messageCandidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { candidate in
                guard !candidate.isEmpty else { return false }
                guard candidate.first != "{" && candidate.first != "[" else { return false }
                let looksLikeCode =
                    candidate.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil
                    || candidate.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
                if looksLikeCode && (candidate.contains("_") || candidate.contains("-")) {
                    return false
                }
                return true
            }

        if let readable = firstReadable, !readable.isEmpty {
            if readable.lowercased().contains("square program failed") {
                return .message("Rewards could not be loaded right now. Please try again shortly.")
            }
            return .message(readable)
        }

        if !raw.isEmpty {
            if raw.first == "{" || raw.first == "[" {
                return .message("Rewards could not be loaded right now. Please try again shortly.")
            }
            return .message(raw)
        }

        return .badStatus(statusCode)
    }

    /// Fetch the loyalty status for a verified phone number.
    /// Also available as `checkStatus(phoneE164:)` for legacy callers.
    func fetchStatus(phoneE164: String) async throws -> LoyaltyStatusResponse {
        try await checkStatus(phoneE164: phoneE164)
    }

    func checkStatus(phoneE164: String) async throws -> LoyaltyStatusResponse {
        let endpoint = BackendRoute.url(for: BackendRoute.loyaltyStatus)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "phone", value: phoneE164)]
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try applyAuthHeaders(&request)

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        do {
            return try JSONDecoder().decode(LoyaltyStatusResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func ensureEnrollment(phoneE164: String, customerID: String? = nil) async throws -> LoyaltyEnrollResponse {
        let endpoint = BackendRoute.url(for: BackendRoute.loyaltyEnroll)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)

        var payload: [String: Any] = ["phone": phoneE164]
        let trimmedCustomerID = customerID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCustomerID.isEmpty {
            payload["customer_id"] = trimmedCustomerID
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        do {
            return try JSONDecoder().decode(LoyaltyEnrollResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func searchAccounts(customerIDs: [String], limit: Int = 10) async throws -> [LoyaltyAccountSummary] {
        let trimmed = customerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmed.isEmpty {
            return []
        }

        let endpoint = BackendRoute.url(for: BackendRoute.loyaltyAccountsSearch)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuthHeaders(&request)

        let payload: [String: Any] = [
            "customer_ids": Array(trimmed.prefix(30)),
            "limit": max(1, min(50, limit))
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        do {
            return try JSONDecoder().decode(LoyaltyAccountsSearchResponse.self, from: data).accounts
        } catch {
            throw APIError.decoding
        }
    }

    func fetchWalletPass(
        phoneE164: String,
        serial: String,
        memberName: String,
        memberId: String,
        phoneNumber: String,
        membershipStartDate: String?,
        tierName: String,
        points: Int
    ) async throws -> Data {
        let endpoint = BackendRoute.url(for: BackendRoute.loyaltyPass)

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "phone", value: phoneE164),
            URLQueryItem(name: "serialNumber", value: serial),
            URLQueryItem(name: "memberName", value: memberName),
            URLQueryItem(name: "memberId", value: memberId),
            URLQueryItem(name: "phoneNumber", value: phoneNumber),
            URLQueryItem(name: "membershipStartDate", value: membershipStartDate),
            URLQueryItem(name: "tierName", value: tierName),
            URLQueryItem(name: "points", value: String(points))
        ]
        
        guard let url = comps.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")
        try applyAuthHeaders(&request)

        let (data, response) = try await CMHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

        guard (200..<300).contains(http.statusCode) else {
            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        return data
    }

    func deleteAccount(phoneE164: String) async throws {
        let trimmedPhone = phoneE164.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            throw APIError.message("A valid phone number is required to delete this account.")
        }

        var last404Error: APIError?
        for pathComponents in BackendRoute.accountDeleteCandidates {
            let endpoint = BackendRoute.url(for: pathComponents)

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try applyAuthHeaders(&request, serviceName: "Account deletion")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["phone": trimmedPhone], options: [])

            let (data, response) = try await CMHTTP.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

            if (200..<300).contains(http.statusCode) {
                return
            }

            if http.statusCode == 404 {
                last404Error = .message("Account deletion endpoint is unavailable.")
                continue
            }

            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        if let last404Error {
            throw last404Error
        }
        throw APIError.message("Account deletion endpoint is unavailable.")
    }

    func postLocationSample(
        phoneE164: String,
        lat: Double,
        lon: Double,
        accuracy: Double,
        timestamp: TimeInterval
    ) async throws {
        let body: [String: Any] = [
            "phone": phoneE164,
            "lat": lat,
            "lon": lon,
            "accuracy": accuracy,
            "timestamp": timestamp
        ]

        let payload = try JSONSerialization.data(withJSONObject: body, options: [])

        var last404Error: APIError?
        for route in BackendRoute.smartCheckInCandidates {
            let url = BackendRoute.url(for: route)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            try applyAuthHeaders(&request, serviceName: "Smart Check-In")
            request.httpBody = payload

            let (data, response) = try await CMHTTP.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.message("No HTTP response") }

            if (200..<300).contains(http.statusCode) {
                return
            }

            if http.statusCode == 404 {
                last404Error = .message("Smart Check-In endpoint is unavailable.")
                continue
            }

            throw friendlyAPIError(statusCode: http.statusCode, data: data, response: http)
        }

        if let last404Error {
            throw last404Error
        }
        throw APIError.message("Smart Check-In endpoint is unavailable.")
    }
}
