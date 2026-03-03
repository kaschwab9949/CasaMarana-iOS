import SwiftUI

struct RewardsRootView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        if session.isUnlocked {
            // Signed-in users with a saved phone should always load live loyalty status.
            if session.activePhoneE164 != nil {
                RewardsWalletView()
            } else {
                RewardsPreviewView()
            }
        } else {
            RewardsAuthEntryView()
        }
    }
}

struct RewardsPreviewView: View {
    @EnvironmentObject var session: AppSession

    private var sampleTiers: [MembershipTier] {
        [
            MembershipTier(id: "member", level: 1, name: "Member", colorName: "member", minPoints: 0, multiplier: 1.0, benefits: [
                "Earn points on purchases",
                "Exclusive event invites"
            ], maxPoints: 499),
            MembershipTier(id: "silver", level: 2, name: "Silver", colorName: "silver", minPoints: 500, multiplier: 1.0, benefits: [
                "Free birthday drink",
                "Early access to special releases"
            ], maxPoints: 1499),
            MembershipTier(id: "gold", level: 3, name: "Gold", colorName: "gold", minPoints: 1500, multiplier: 1.1, benefits: [
                "10% bonus points",
                "Invite to annual Gold member party"
            ], maxPoints: 3999),
            MembershipTier(id: "inner", level: 4, name: "The Inner Circle", colorName: "inner", minPoints: 4000, multiplier: 1.25, benefits: [
                "Top tier perks and premium offers"
            ], maxPoints: nil),
        ]
    }

    var body: some View {
        List {
            Section {
                Text("Set Up Rewards")
                    .font(.headline)
                
                Text("Sign in with your Casa Marana app login to load your points and loyalty status from Square using your verified phone number.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Preview Tiers") {
                ForEach(sampleTiers) { tier in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tier.name)
                                .font(.headline)
                                .foregroundStyle(tier.color)
                            Spacer()
                            Text("\(tier.minPoints) pts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(tier.benefitsSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Label("After sign-in, you can add your rewards pass to Apple Wallet.", systemImage: "wallet.pass")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .listStyle(.insetGrouped)
    }
}
