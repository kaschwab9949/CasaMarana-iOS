import Foundation
import SwiftUI

struct MembershipTier: Identifiable {
    let id: String
    let level: Int
    let name: String
    let colorName: String
    let minPoints: Int
    let multiplier: Double
    let benefits: [String]
    let maxPoints: Int?

    /// Human-readable summary of all benefits joined into one string.
    var benefitsSummary: String {
        benefits.joined(separator: ". ")
    }

    var color: Color {
        switch colorName.lowercased() {
        case "mint", "member":  return .mint
        case "yellow":          return .yellow
        case "orange":          return .orange
        case "purple", "inner": return .purple
        case "black":           return .black
        case "silver":          return .gray
        case "gold":            return .yellow
        default:                return .gray
        }
    }

    static let all: [MembershipTier] = [
        MembershipTier(id: "tier_ambassador", level: 1, name: "Ambassador", colorName: "Mint", minPoints: 0, multiplier: 1.0, benefits: [
            "1x points on purchases",
            "Birthday Reward",
            "Early Access to Events"
        ], maxPoints: 999),
        MembershipTier(id: "tier_gold", level: 2, name: "Gold", colorName: "Yellow", minPoints: 1000, multiplier: 1.25, benefits: [
            "1.25x points on purchases",
            "Birthday Reward",
            "Early Access to Events",
            "Free Merch Item Annually"
        ], maxPoints: 2499),
        MembershipTier(id: "tier_platinum", level: 3, name: "Platinum", colorName: "Orange", minPoints: 2500, multiplier: 1.5, benefits: [
            "1.5x points on purchases",
            "Birthday Reward",
            "Early Access to Events",
            "Free Merch Item Annually",
            "VIP Seating Privileges"
        ], maxPoints: 4999),
        MembershipTier(id: "tier_diamond", level: 4, name: "Diamond", colorName: "Purple", minPoints: 5000, multiplier: 2.0, benefits: [
            "2x points on purchases",
            "Birthday Reward",
            "Early Access to Events",
            "Free Merch Item Annually",
            "VIP Seating Privileges",
            "Exclusive Diamond Events"
        ], maxPoints: 9999),
        MembershipTier(id: "tier_black", level: 5, name: "Black Card", colorName: "Black", minPoints: 10000, multiplier: 3.0, benefits: [
            "3x points on purchases",
            "All Lower Tier Benefits",
            "Concierge Service",
            "Private Tasting Invites"
        ], maxPoints: nil)
    ]

    static func tier(for points: Int) -> MembershipTier {
        let sorted = all.sorted { $0.level > $1.level }
        for t in sorted {
            if points >= t.minPoints { return t }
        }
        return all.first! // Ambassador fallback
    }

    static func nextTier(after currentLevel: Int) -> MembershipTier? {
        all.first { $0.level == currentLevel + 1 }
    }
}
