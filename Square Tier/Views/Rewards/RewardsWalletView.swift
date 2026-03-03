import SwiftUI
import PassKit

struct RewardsWalletView: View {
    @EnvironmentObject var session: AppSession

    @State private var status: LoyaltyStatusResponse? = nil
    @State private var isLoading: Bool = false
    @State private var isEnrolling: Bool = false
    @State private var errorText: String? = nil
    @State private var infoText: String? = nil
    @State private var nextRefreshAllowedAt: Date = .distantPast
    @State private var accountSummary: LoyaltyAccountSummary? = nil

    @State private var passToAdd: PassWrapper? = nil

    private let loyaltyAPI = LoyaltyAPI()

    private func normalizedRewardTiers(from status: LoyaltyStatusResponse) -> [RewardTier] {
        if !status.rewardTiers.isEmpty {
            return status.rewardTiers
        }

        // Fallback to app-defined thresholds so tier/reward progression remains visible
        // even when backend only returns points + enrollment.
        return MembershipTier.all.map {
            RewardTier(id: $0.id, name: $0.name, points: $0.minPoints)
        }
    }

    private func displayTierName(for status: LoyaltyStatusResponse) -> String {
        if let backendTier = status.tierName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !backendTier.isEmpty {
            return backendTier
        }
        return currentTierName(points: status.points, tiers: normalizedRewardTiers(from: status))
    }

    private func availableRewards(for status: LoyaltyStatusResponse) -> [String] {
        if !status.availableRewards.isEmpty {
            return status.availableRewards
        }
        return MembershipTier.tier(for: status.points).benefits
    }

    private var phoneE164: String {
        session.activePhoneE164 ?? ""
    }

    private var maskedLookupPhone: String {
        let digits = phoneE164.filter(\.isNumber)
        guard !digits.isEmpty else { return "Unavailable" }
        let suffix = String(digits.suffix(4))
        if suffix.isEmpty {
            return "Unavailable"
        }
        return "••• ••• \(suffix)"
    }

    private func maskedPhone(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        return "••• ••• \(digits.suffix(4))"
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = iso.date(from: trimmed) {
            return parsed
        }

        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]
        if let parsed = isoNoFraction.date(from: trimmed) {
            return parsed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: trimmed) {
                return parsed
            }
        }

        return nil
    }

    private func memberSinceText(status: LoyaltyStatusResponse) -> String? {
        let candidates: [String?] = [
            status.membershipStartDate,
            accountSummary?.enrolledAt,
            accountSummary?.createdAt
        ]

        for candidate in candidates {
            if let date = parseDate(candidate) {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
        }

        return nil
    }

    private func currentTierName(points: Int, tiers: [RewardTier]) -> String {
        guard !tiers.isEmpty else { return "Member" }
        let sorted = tiers.sorted { $0.points < $1.points }
        var best: RewardTier? = nil
        for t in sorted where points >= t.points { best = t }
        return best?.name ?? "Member"
    }

    private var rewardsLoadBanner: (text: String, color: Color)? {
        if isLoading {
            return ("Loading Square rewards...", .secondary)
        }
        if errorText != nil {
            return ("Square rewards are temporarily unavailable. Tap Refresh to try again.", .red)
        }
        guard let status else { return nil }
        if status.enrolled {
            return ("Loaded enrolled Square rewards account.", .green)
        }
        return ("Loaded account. This phone is not enrolled in Square Loyalty yet.", .secondary)
    }

    private func rewardsForTier(_ tier: RewardTier) -> [String] {
        if let match = MembershipTier.all.first(where: { $0.name.caseInsensitiveCompare(tier.name) == .orderedSame }) {
            return match.benefits
        }
        return ["In-store loyalty reward"]
    }

    private func customerSegmentLabels(for status: LoyaltyStatusResponse) -> [String] {
        var labels = status.customerSegments.map { segment in
            let name = segment.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? segment.id : name
        }

        if labels.isEmpty {
            labels = status.segmentIDs
        }

        var seen = Set<String>()
        var uniqueLabels: [String] = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                uniqueLabels.append(trimmed)
            }
        }
        return uniqueLabels
    }

    private func customerGroupLabels(for status: LoyaltyStatusResponse) -> [String] {
        var labels = status.customerGroups.map { group in
            let name = group.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? group.id : name
        }

        if labels.isEmpty {
            labels = status.groupIDs
        }

        var seen = Set<String>()
        var uniqueLabels: [String] = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                uniqueLabels.append(trimmed)
            }
        }
        return uniqueLabels
    }

    private func loadStatus() async {
        guard !phoneE164.isEmpty else {
            await MainActor.run { self.errorText = "Missing phone number." }
            return
        }

        guard !isLoading else { return }

        let now = Date()
        guard now >= nextRefreshAllowedAt else {
            let wait = max(1, Int(ceil(nextRefreshAllowedAt.timeIntervalSince(now))))
            await MainActor.run {
                self.errorText = "Please wait \(wait) seconds before trying Refresh again."
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorText = nil
        }

        do {
            let res = try await loyaltyAPI.fetchStatus(phoneE164: phoneE164)
            var fetchedAccount: LoyaltyAccountSummary? = nil
            if let customerID = res.customerID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !customerID.isEmpty {
                do {
                    fetchedAccount = try await loyaltyAPI.searchAccounts(customerIDs: [customerID], limit: 1).first
                } catch {
                    // Best-effort enrichment. Status should still load even if account search fails.
                }
            }

            await MainActor.run {
                self.status = res
                if let fetchedAccount {
                    self.accountSummary = fetchedAccount
                } else if !res.enrolled {
                    self.accountSummary = nil
                }
                self.isLoading = false
                self.nextRefreshAllowedAt = Date().addingTimeInterval(5)
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                if let apiError = error as? APIError, case let .rateLimited(retryAfter) = apiError {
                    let wait = max(15, Int(ceil(retryAfter ?? 60)))
                    self.nextRefreshAllowedAt = Date().addingTimeInterval(TimeInterval(wait))
                }
                self.errorText = UserFacingError.message(
                    for: error,
                    context: .rewards,
                    fallback: "Failed to load rewards."
                )
            }
        }
    }

    private func enrollmentNotAllowedMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited(let retryAfter):
                let wait = max(15, Int(ceil(retryAfter ?? 60)))
                return "Square enrollment is temporarily busy. Try again in \(wait) seconds."
            case .message(let message):
                let lowered = message.lowercased()
                if lowered.contains("route is unavailable")
                    || lowered.contains("not available")
                    || lowered.contains("not supported")
                    || lowered.contains("not allowed")
                    || lowered.contains("cannot be enrolled")
                    || lowered.contains("in-store transaction") {
                    return "In-app enrollment is not available for this Square loyalty program. Complete enrollment in-store, then tap Refresh."
                }
            default:
                break
            }
        }

        return UserFacingError.message(
            for: error,
            context: .rewards,
            fallback: "Could not enroll this phone in Square rewards right now."
        )
    }

    private func enrollInSquareRewardsIfAvailable() async {
        guard !phoneE164.isEmpty else {
            await MainActor.run {
                self.errorText = "Missing phone number."
            }
            return
        }

        if status == nil {
            await loadStatus()
        }

        guard let currentStatus = status else {
            await MainActor.run {
                self.errorText = "Could not load rewards status. Tap Refresh and try again."
            }
            return
        }

        guard !currentStatus.enrolled else {
            await MainActor.run {
                self.infoText = "This phone is already enrolled in Square rewards."
            }
            return
        }

        await MainActor.run {
            self.isEnrolling = true
            self.infoText = nil
            self.errorText = nil
        }

        do {
            let result = try await loyaltyAPI.ensureEnrollment(
                phoneE164: phoneE164,
                customerID: currentStatus.customerID
            )

            if result.enrolled || result.created {
                await MainActor.run {
                    self.infoText = "Enrollment succeeded. Refreshing rewards…"
                    if let account = result.account {
                        self.accountSummary = account
                    }
                }
                await loadStatus()
                await MainActor.run {
                    if self.status?.enrolled == true {
                        self.infoText = "Square rewards enrollment is active for this phone."
                    } else {
                        self.infoText = "Enrollment was requested. If points are not visible yet, tap Refresh again in a moment."
                    }
                    self.isEnrolling = false
                }
            } else {
                await MainActor.run {
                    self.errorText = "Square did not allow in-app enrollment for this phone yet. Complete enrollment in-store, then tap Refresh."
                    self.isEnrolling = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorText = enrollmentNotAllowedMessage(for: error)
                self.isEnrolling = false
            }
        }
    }

    private func buildAndPresentPass() async {
        guard let s = status else { return }

        let name = session.profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = name.isEmpty ? "Casa Marana Member" : name
        let tierName = displayTierName(for: s)

        // The ID shouldn't change for the user if they're the same person.
        // For Apple Wallet, using the phone number as the member id is typical if there is no internal GUID.
        let memberId = phoneE164.replacingOccurrences(of: "+", with: "")
        let phoneForPass = s.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (s.phoneNumber ?? phoneE164)
            : phoneE164

        // The Apple Wallet pass serial number must be unique per pass added to Apple Wallet.
        // Usually backend handles this, but since we are generating passes here we'll use a combination of user id and a timestamp or UUID.
        let serial = "\(memberId)-\(UUID().uuidString.prefix(6))"

        do {
            let data = try await loyaltyAPI.fetchWalletPass(
                phoneE164: phoneE164,
                serial: serial,
                memberName: safeName,
                memberId: memberId,
                phoneNumber: phoneForPass,
                membershipStartDate: s.membershipStartDate,
                tierName: tierName,
                points: s.points
            )

            let pass = try PKPass(data: data)
            await MainActor.run {
                self.passToAdd = PassWrapper(pass: pass)
            }
        } catch {
            await MainActor.run {
                self.errorText = UserFacingError.message(
                    for: error,
                    context: .wallet,
                    fallback: "Could not load Apple Wallet pass."
                )
            }
        }
    }

    private func addWalletPassTapped() {
        Task {
            if status == nil {
                await loadStatus()
            }

            guard let s = status else {
                await MainActor.run {
                    self.errorText = "Load rewards first, then try adding your Wallet pass."
                }
                return
            }

            guard s.enrolled else {
                await MainActor.run {
                    self.errorText = "This phone is not enrolled in Square Loyalty yet, so a Wallet pass cannot be added."
                }
                return
            }

            await buildAndPresentPass()
        }
    }

    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack { ProgressView(); Text("Loading rewards…") }
                        .accessibilityIdentifier("rewards.wallet.loadingState")
                }

                Text("Linked phone: \(maskedLookupPhone)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("rewards.wallet.lookupPhoneText")

                if let banner = rewardsLoadBanner {
                    Text(banner.text)
                        .font(.footnote)
                        .foregroundStyle(banner.color)
                        .accessibilityIdentifier("rewards.wallet.loadStateText")
                }

                Text("Points, balance, and loyalty status are pulled directly from Square using this verified phone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let err = errorText {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("rewards.wallet.errorText")
                }

                if let info = infoText {
                    Text(info)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .accessibilityIdentifier("rewards.wallet.infoText")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Wallet Pass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let s = status, s.enrolled {
                        AddToWalletButton {
                            addWalletPassTapped()
                        }
                        .frame(height: 50)
                        .padding(.top, 4)
                        .accessibilityIdentifier("rewards.wallet.addToWalletButton")

                        Text("Add your rewards pass to Apple Wallet for quick check-in at checkout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            addWalletPassTapped()
                        } label: {
                            Label("Add to Apple Wallet", systemImage: "wallet.pass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("rewards.wallet.addToWalletFallbackButton")

                        if isLoading {
                            Text("Checking rewards enrollment…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if status != nil {
                            Text("Finish Square Loyalty enrollment in-store, then tap Refresh to enable pass creation.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Tap Refresh to load your rewards account, then add your pass.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)

                if let s = status {
                    if s.enrolled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Loyalty Status")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text(displayTierName(for: s))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.mint)

                            Text("\(s.points) pts")
                                .font(.headline)
                                .fontWeight(.semibold)

                            if let memberSince = memberSinceText(status: s) {
                                Label("Member since \(memberSince)", systemImage: "calendar")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let squarePhone = maskedPhone(s.phoneNumber), squarePhone != maskedLookupPhone {
                                Label("Square phone on file: \(squarePhone)", systemImage: "phone")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let lifetimePoints = accountSummary?.lifetimePoints, lifetimePoints > 0 {
                                Label("Lifetime points earned: \(lifetimePoints)", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let squareBalance = accountSummary?.balance, squareBalance > 0, squareBalance != s.points {
                                Label("Square balance: \(squareBalance) pts", systemImage: "number.circle")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This phone (\(maskedLookupPhone)) is not enrolled in Square Loyalty yet.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("rewards.wallet.notEnrolledText")

                            Button {
                                Task { await enrollInSquareRewardsIfAvailable() }
                            } label: {
                                HStack {
                                    if isEnrolling { ProgressView() }
                                    Text(isEnrolling ? "Enrolling…" : "Enroll in Square Rewards (If Available)")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isEnrolling || isLoading)
                            .accessibilityIdentifier("rewards.wallet.enrollButton")

                            Text("We can enroll this phone in-app only when your Square loyalty program allows it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No rewards data loaded yet.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("rewards.wallet.noDataText")
                }

                Button {
                    Task { await loadStatus() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("rewards.wallet.refreshButton")
                .disabled(isLoading || Date() < nextRefreshAllowedAt)

                if Date() < nextRefreshAllowedAt {
                    Text("Refresh available in \(max(1, Int(ceil(nextRefreshAllowedAt.timeIntervalSinceNow))))s.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let s = status, s.enrolled, !availableRewards(for: s).isEmpty {
                Section("Available Rewards") {
                    ForEach(Array(availableRewards(for: s).prefix(6).enumerated()), id: \.offset) { _, item in
                        Text(item)
                    }
                }
            }

            if let s = status, s.enrolled, !customerSegmentLabels(for: s).isEmpty {
                Section("Customer Segments") {
                    ForEach(Array(customerSegmentLabels(for: s).prefix(6)), id: \.self) { segment in
                        Text(segment)
                    }

                    Text("Segments are managed in Square Dashboard and synced read-only in the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let s = status, s.enrolled, !customerGroupLabels(for: s).isEmpty {
                Section("Customer Groups") {
                    ForEach(Array(customerGroupLabels(for: s).prefix(6)), id: \.self) { group in
                        Text(group)
                    }

                    Text("Groups are manual collections managed in Square Dashboard and synced read-only in the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let s = status, s.enrolled {
                let tiers = normalizedRewardTiers(from: s)

                Section("Rewards You Can Get") {
                    ForEach(tiers.sorted(by: { $0.points < $1.points })) { tier in
                        let unlocked = s.points >= tier.points
                        let pointsNeeded = max(0, tier.points - s.points)
                        let rewards = rewardsForTier(tier)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tier.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(tier.points)+ pts")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(rewards.prefix(3), id: \.self) { item in
                                Text("• \(item)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text(unlocked ? "Unlocked" : "Need \(pointsNeeded) more points")
                                .font(.caption)
                                .foregroundStyle(unlocked ? .mint : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("rewards.wallet.list")
        .task { await loadStatus() }
        .sheet(item: $passToAdd) { wrapper in
            AddPassesPresenter(pass: wrapper.pass) {
                passToAdd = nil
            }
        }
    }
}

private struct PassWrapper: Identifiable {
    let id = UUID()
    let pass: PKPass
}
