//
//  Square_TierTests.swift
//  Square TierTests
//
//  Created by Kyle Schwab on 12/14/25.
//

import XCTest
@testable import Casa_Marana

final class Casa_MaranaTests: XCTestCase {
    func testNormalizePhoneE164_accepts10DigitUSNumber() {
        XCTAssertEqual(normalizePhoneE164("5205551234"), "+15205551234")
    }

    func testNormalizePhoneE164_accepts11DigitUSNumberWithLeadingOne() {
        XCTAssertEqual(normalizePhoneE164("15205551234"), "+15205551234")
    }

    func testNormalizePhoneE164_rejectsInvalidLengths() {
        XCTAssertNil(normalizePhoneE164("555123"))
        XCTAssertNil(normalizePhoneE164("99915205551234"))
    }

    func testNormalizePhoneE164_normalizesFormattedInput() {
        XCTAssertEqual(normalizePhoneE164("(520) 555-1234"), "+15205551234")
        XCTAssertEqual(normalizePhoneE164("+1 (520) 555-1234"), "+15205551234")
    }

    func testUserProfileRoundTripCodable() throws {
        let original = UserProfile(
            fullName: "Test Member",
            phoneE164: "+15205551234",
            email: "member@example.com",
            birthday: "1990-01-01",
            isPhoneVerified: true,
            phoneVerificationToken: "token_abc"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testMembershipTierStateLogic() {
        let ambassador = MembershipTier.tier(for: 0)
        XCTAssertEqual(ambassador.level, 1)
        XCTAssertEqual(ambassador.name, "Ambassador")

        let gold = MembershipTier.tier(for: 1200)
        XCTAssertEqual(gold.level, 2)
        XCTAssertEqual(gold.name, "Gold")

        let nextAfterGold = MembershipTier.nextTier(after: gold.level)
        XCTAssertEqual(nextAfterGold?.level, 3)
        XCTAssertEqual(nextAfterGold?.name, "Platinum")

        let blackCard = MembershipTier.tier(for: 20_000)
        XCTAssertEqual(blackCard.level, 5)
        XCTAssertNil(MembershipTier.nextTier(after: blackCard.level))
    }
}
