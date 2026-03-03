import SwiftUI
import PassKit

struct RewardsWalletView: View {
    @EnvironmentObject var session: AppSession

    @State private var status: LoyaltyStatusResponse? = nil
    @State private var isLoading: Bool = false
    @State private var errorText: String? = nil
    @State private var nextRefreshAllowedAt: Date = .distantPast

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

    private func currentTierName(points: Int, tiers: [RewardTier]) -> String {
        guard !tiers.isEmpty else { return "Member" }
        let sorted = tiers.sorted { $0.points < $1.points }
        var best: RewardTier? = nil
        for t in sorted where points >= t.points { best = t }
        return best?.name ?? "Member"
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
            await MainActor.run {
                self.status = res
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

                if let err = errorText {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("rewards.wallet.errorText")
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

                            Text("Your loyalty pass shows the business name, available point balance, membership start date, account holder name, and phone number.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("After adding it to Wallet, tap the seller display or contactless reader at checkout to check in, earn points, and redeem rewards.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Adding loyalty passes is only available on iOS devices.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("This phone (\(maskedLookupPhone)) is not enrolled in Square Loyalty yet. Complete enrollment after an in-store transaction, then refresh.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("rewards.wallet.notEnrolledText")
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
