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
            email: "member@casamarana.com",
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

    func testSnakeBoardMetricsGuardsInvalidContainerDimensions() {
        let invalid = SnakeGameView.resolvedBoardMetrics(
            containerSize: CGSize(width: CGFloat.infinity, height: -CGFloat.infinity),
            cols: 20
        )

        XCTAssertTrue(invalid.boardSide.isFinite)
        XCTAssertTrue(invalid.cellSize.isFinite)
        XCTAssertGreaterThan(invalid.boardSide, 0)
        XCTAssertGreaterThan(invalid.cellSize, 0)
    }

    func testSnakeBoardMetricsGuardsNaNAndZeroColumns() {
        let metrics = SnakeGameView.resolvedBoardMetrics(
            containerSize: CGSize(width: CGFloat.nan, height: 300),
            cols: 0
        )

        XCTAssertTrue(metrics.boardSide.isFinite)
        XCTAssertTrue(metrics.cellSize.isFinite)
        XCTAssertGreaterThan(metrics.boardSide, 0)
        XCTAssertGreaterThan(metrics.cellSize, 0)
    }

    func testSnakeBoardMetricsKeepsPlayableBoardSizeOnPhoneWidth() {
        let metrics = SnakeGameView.resolvedBoardMetrics(
            containerSize: CGSize(width: 390, height: 470),
            cols: 20
        )

        XCTAssertGreaterThanOrEqual(metrics.boardSide, 290)
        XCTAssertGreaterThan(metrics.cellSize, 10)
    }

    func testMenuCategoryMappingClassifiesDrinksFromCategory() {
        let item = MenuItem(
            id: "1",
            name: "House Margarita",
            description: "",
            price: "$10.00",
            category: "Mixed Drinks",
            tags: ["cocktail"]
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .drinks)
    }

    func testMenuCategoryMappingClassifiesFoodFromKeywords() {
        let item = MenuItem(
            id: "2",
            name: "Chicken Wings",
            description: "",
            price: "$12.00",
            category: "Specials",
            tags: ["shareable"]
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .food)
    }

    func testMenuCategoryMappingUsesSectionHintFirst() {
        let item = MenuItem(
            id: "3",
            name: "House Margarita",
            description: "",
            price: "$10.00",
            category: "Menu",
            tags: ["Menu"],
            sectionHint: "drink"
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .drinks)
    }

    func testMenuCategoryMappingUsesSquareTagWhenCategoryIsMenu() {
        let item = MenuItem(
            id: "4",
            name: "Anejo Azul",
            description: "",
            price: "$12.00",
            category: "Menu",
            tags: ["Spirits", "Tequila/Mezcal", "Drinks"],
            sectionHint: nil
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .drinks)
    }

    func testMenuCategoryMappingUsesCategoryWhenSectionHintIsOther() {
        let item = MenuItem(
            id: "5",
            name: "Martini",
            description: "",
            price: "$14.00",
            category: "Cocktails",
            tags: ["Drinks"],
            sectionHint: "other"
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .drinks)
    }

    func testMenuCategoryMappingDoesNotTreatGenericMenuWordAsFood() {
        let item = MenuItem(
            id: "6",
            name: "Weekend Menu",
            description: "",
            price: "",
            category: "Menu",
            tags: [],
            sectionHint: nil
        )
        XCTAssertEqual(MenuCategoryMapping.classify(item), .other)
    }

    func testCMHTTPApplyAuthHeadersAPIKeyMode() {
        var request = URLRequest(url: URL(string: "https://casa-marana-backend.vercel.app")!)
        let applied = CMHTTP.applyAuthHeaders(&request, apiKey: "abc123", authHeaderMode: .apiKey)
        XCTAssertTrue(applied)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "abc123")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testCMHTTPApplyAuthHeadersBearerModeStripsPrefix() {
        var request = URLRequest(url: URL(string: "https://casa-marana-backend.vercel.app")!)
        let applied = CMHTTP.applyAuthHeaders(&request, apiKey: "Bearer token123", authHeaderMode: .bearer)
        XCTAssertTrue(applied)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
        XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
    }

    func testEventsExtractorAcceptsSingleQuotedHrefAndSkipsListingLinks() {
        let html = """
        <a href='/events/'>Events Home</a>
        <a href='/events/calendar'>Calendar</a>
        <a href='/events/2026/3/3/generalwebp?format=ical'>ICS</a>
        <a href='/events/2026/3/3/generalwebp'>Event Page</a>
        <a href='https://www.casamarana.com/events/2026/3/3/generalwebp#frag'>Duplicate</a>
        """

        let urls = EventsFeedModel.debugExtractEventURLs(from: html)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://www.casamarana.com/events/2026/3/3/generalwebp")
    }

    func testBackendRouteCandidateOrderIsCanonicalFirst() {
        XCTAssertEqual(BackendRoute.smartCheckInCandidates.first, BackendRoute.smartCheckInCanonical)
        XCTAssertEqual(BackendRoute.accountDeleteCandidates.first, BackendRoute.accountDeleteCanonical)
        XCTAssertEqual(BackendRoute.menuCandidates.first, BackendRoute.menuCanonical)
        XCTAssertEqual(BackendRoute.phoneStartCandidates.first, BackendRoute.phoneStart)
        XCTAssertEqual(BackendRoute.phoneVerifyCandidates.first, BackendRoute.phoneVerify)
    }
}
