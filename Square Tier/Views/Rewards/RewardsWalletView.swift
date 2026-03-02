import SwiftUI
import PassKit

struct RewardsWalletView: View {
    @EnvironmentObject var session: AppSession

    @State private var status: LoyaltyStatusResponse? = nil
    @State private var isLoading: Bool = false
    @State private var errorText: String? = nil

    @State private var passToAdd: PassWrapper? = nil

    private let loyaltyAPI = LoyaltyAPI()

    private var phoneE164: String {
        session.verifiedPhoneE164 ?? ""
    }

    private func currentTierName(points: Int, tiers: [RewardTier]) -> String {
        guard !tiers.isEmpty else { return "Member" }
        let sorted = tiers.sorted { $0.points < $1.points }
        var best: RewardTier? = nil
        for t in sorted where points >= t.points { best = t }
        return best?.name ?? "Member"
    }

    private func loadStatus() async {
        guard !phoneE164.isEmpty else {
            await MainActor.run { self.errorText = "Missing phone number." }
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
            }
        } catch {
            await MainActor.run {
                self.status = nil
                self.isLoading = false
                self.errorText = (error as? LocalizedError)?.errorDescription ?? "Failed to load rewards."
            }
        }
    }

    private func buildAndPresentPass() async {
        guard let s = status else { return }

        let name = session.profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = name.isEmpty ? "Casa Marana Member" : name
        let tierName = currentTierName(points: s.points, tiers: s.rewardTiers)

        // The ID shouldn't change for the user if they're the same person.
        // For Apple Wallet, using the phone number as the member id is typical if there is no internal GUID.
        let memberId = phoneE164.replacingOccurrences(of: "+", with: "")

        // The Apple Wallet pass serial number must be unique per pass added to Apple Wallet.
        // Usually backend handles this, but since we are generating passes here we'll use a combination of user id and a timestamp or UUID.
        let serial = "\(memberId)-\(UUID().uuidString.prefix(6))"

        do {
            let data = try await loyaltyAPI.fetchWalletPass(
                phoneE164: phoneE164,
                serial: serial,
                memberName: safeName,
                memberId: memberId,
                tierName: tierName,
                points: s.points
            )

            let pass = try PKPass(data: data)
            await MainActor.run {
                self.passToAdd = PassWrapper(pass: pass)
            }
        } catch {
            // If the backend API isn't built yet, we fallback to a bundled dummy pass if one exists.
            if let bundleData = WalletPassBundleFallback.loadBundledPassData(),
               let pass = try? PKPass(data: bundleData) {
                await MainActor.run {
                    self.passToAdd = PassWrapper(pass: pass)
                }
            } else {
                await MainActor.run {
                    self.errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load Apple Wallet pass."
                }
            }
        }
    }

    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack { ProgressView(); Text("Loading rewards…") }
                        .accessibilityIdentifier("rewards.wallet.loadingState")
                }

                if let err = errorText {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("rewards.wallet.errorText")
                }

                if let s = status {
                    if s.enrolled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Tier")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(currentTierName(points: s.points, tiers: s.rewardTiers))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.mint)

                            Text("\(s.points) pts")
                                .font(.headline)
                                .fontWeight(.semibold)

                            AddToWalletButton {
                                Task { await buildAndPresentPass() }
                            }
                            .frame(height: 50)
                            .padding(.top, 12)
                            .accessibilityIdentifier("rewards.wallet.addToWalletButton")
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("Phone number is not enrolled in rewards yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No rewards data loaded yet.")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await loadStatus() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("rewards.wallet.refreshButton")
            }

            if let s = status, !s.rewardTiers.isEmpty {
                Section("Reward Tiers") {
                    ForEach(s.rewardTiers.sorted(by: { $0.points < $1.points })) { t in
                        HStack {
                            Text(t.name)
                            Spacer()
                            Text("\(t.points)+")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
