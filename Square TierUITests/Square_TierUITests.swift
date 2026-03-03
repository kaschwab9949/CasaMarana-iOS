//
//  Square_TierUITests.swift
//  Square TierUITests
//
//  Created by Kyle Schwab on 12/14/25.
//

import XCTest

final class Casa_MaranaUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing-reset-session", "-ui-testing-selected-tab", "rewards", "-ui-testing-seed-demo-account"]

        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let preferredButtons = ["Allow While Using App", "Allow Once", "OK", "Don’t Allow", "Don't Allow"]
            for label in preferredButtons where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()
        app.tap()
    }

    @MainActor
    func testTabNavigationAndCoreSmokeFlow() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(element(withID: "screen.rewards").waitForExistence(timeout: 5), "Rewards screen did not appear after launch.")

        let phoneField = app.textFields.matching(identifier: "rewards.auth.phoneField").firstMatch
        let pinField = app.secureTextFields.matching(identifier: "rewards.auth.pinField").firstMatch
        let signInButton = app.buttons["rewards.auth.signInButton"]

        XCTAssertTrue(phoneField.waitForExistence(timeout: 5))
        XCTAssertTrue(pinField.waitForExistence(timeout: 5))
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        clearAndType(text: "5205551234", into: phoneField)
        clearAndType(text: "1234", into: pinField)
        signInButton.tap()

        let refreshButton = app.buttons["rewards.wallet.refreshButton"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 8))
        refreshButton.tap()
        assertRewardsRefreshOutcomeAppeared()

        selectTab(named: "Events")
        XCTAssertTrue(element(withID: "screen.events").waitForExistence(timeout: 5), "Events screen did not appear after selecting Events tab.")

        selectTab(named: "Menu")
        XCTAssertTrue(element(withID: "screen.menu").waitForExistence(timeout: 5), "Menu screen did not appear after selecting Menu tab.")

        let foodSegment = app.buttons["Food"]
        let drinksSegment = app.buttons["Drinks"]
        XCTAssertTrue(foodSegment.waitForExistence(timeout: 5), "Food section control should be visible.")
        XCTAssertTrue(drinksSegment.waitForExistence(timeout: 5), "Drinks section control should be visible.")
        drinksSegment.tap()

        let searchField = app.searchFields["Search pizzas, drinks, etc."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        clearAndType(text: "Titos", into: searchField)
        XCTAssertTrue(app.staticTexts["Titos Vodka"].waitForExistence(timeout: 5))

        dismissKeyboardIfVisible()
        selectTab(named: "Home")
        XCTAssertTrue(element(withID: "screen.home").waitForExistence(timeout: 5), "Home screen did not appear after selecting Home tab.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let launchApp = XCUIApplication()
            launchApp.launchArguments.append("-ui-testing-reset-session")
            launchApp.launch()
        }
    }

    @MainActor
    func testRewardsSignInValidationShowsPhoneAndPINErrors() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(element(withID: "screen.rewards").waitForExistence(timeout: 5), "Rewards screen did not appear after launch.")

        let phoneField = app.textFields.matching(identifier: "rewards.auth.phoneField").firstMatch
        let pinField = app.secureTextFields.matching(identifier: "rewards.auth.pinField").firstMatch
        let signInButton = app.buttons["rewards.auth.signInButton"]
        let authError = element(withID: "rewards.auth.errorText")

        XCTAssertTrue(phoneField.waitForExistence(timeout: 5))
        XCTAssertTrue(pinField.waitForExistence(timeout: 5))
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        clearAndType(text: "52055", into: phoneField)
        clearAndType(text: "12", into: pinField)
        signInButton.tap()

        XCTAssertTrue(authError.waitForExistence(timeout: 5), "Expected auth validation error after invalid phone input.")
        XCTAssertTrue(authError.label.localizedCaseInsensitiveContains("10-digit"), "Expected phone validation error. Actual: \(authError.label)")

        clearAndType(text: "51234", into: phoneField)
        signInButton.tap()

        XCTAssertTrue(authError.waitForExistence(timeout: 5), "Expected auth validation error for short PIN.")
        XCTAssertTrue(authError.label.localizedCaseInsensitiveContains("pin"), "Expected PIN validation error. Actual: \(authError.label)")
    }

    @MainActor
    func testOverflowTabsAndSettingsEraseFlow() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(element(withID: "screen.rewards").waitForExistence(timeout: 5), "Rewards screen did not appear after launch.")

        let phoneField = app.textFields.matching(identifier: "rewards.auth.phoneField").firstMatch
        let pinField = app.secureTextFields.matching(identifier: "rewards.auth.pinField").firstMatch
        let signInButton = app.buttons["rewards.auth.signInButton"]

        XCTAssertTrue(phoneField.waitForExistence(timeout: 5))
        XCTAssertTrue(pinField.waitForExistence(timeout: 5))
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        clearAndType(text: "5205551234", into: phoneField)
        clearAndType(text: "1234", into: pinField)
        signInButton.tap()

        XCTAssertTrue(app.buttons["rewards.wallet.refreshButton"].waitForExistence(timeout: 8), "Rewards wallet did not load after sign-in.")

        selectTab(named: "Play Snake")
        XCTAssertTrue(element(withID: "screen.snake").waitForExistence(timeout: 5), "Snake screen did not appear after selecting overflow tab.")
        XCTAssertTrue(element(withID: "snake.control.up").waitForExistence(timeout: 5), "Snake up control button should be visible.")
        XCTAssertTrue(element(withID: "snake.control.left").waitForExistence(timeout: 5), "Snake left control button should be visible.")
        XCTAssertTrue(element(withID: "snake.control.right").waitForExistence(timeout: 5), "Snake right control button should be visible.")
        XCTAssertTrue(element(withID: "snake.control.down").waitForExistence(timeout: 5), "Snake down control button should be visible.")
        XCTAssertTrue(element(withID: "snake.leaderboard.section").waitForExistence(timeout: 5), "Snake leaderboard section should be visible.")

        selectTab(named: "Settings")
        XCTAssertTrue(element(withID: "screen.settings").waitForExistence(timeout: 5), "Settings screen did not appear after selecting overflow tab.")

        let eraseButton = app.buttons["settings.eraseLocalProfileButton"]
        XCTAssertTrue(
            waitForElementByScrollingToVisible(eraseButton, timeout: 8),
            "Erase Local Profile button should exist after sign-in."
        )

        eraseButton.tap()
        let cancelButton = app.buttons.matching(identifier: "settings.eraseCancelButton").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Erase confirmation cancel button did not appear.")
        cancelButton.tap()

        XCTAssertTrue(eraseButton.waitForExistence(timeout: 5), "Erase Local Profile button should still exist after cancellation.")

        eraseButton.tap()
        let confirmButton = app.buttons.matching(identifier: "settings.eraseConfirmButton").firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Erase confirmation button did not appear.")
        confirmButton.tap()

        let noProfileText = app.staticTexts["settings.noLocalProfileText"]
        XCTAssertTrue(noProfileText.waitForExistence(timeout: 5), "No-local-profile state did not appear after erase confirmation.")
    }

    private func selectTab(named expectedLabel: String) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let buttons = tabBar.buttons.allElementsBoundByIndex
        let labels = buttons.map { $0.label }.joined(separator: ", ")
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", expectedLabel, expectedLabel)

        let directMatch = tabBar.buttons.matching(predicate).firstMatch
        if directMatch.waitForExistence(timeout: 2) {
            directMatch.tap()
            return
        }

        // Fallback for cases where tabs are presented in a "More" overflow list.
        let moreButton = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'More' OR identifier CONTAINS[c] 'More'")).firstMatch
        if moreButton.waitForExistence(timeout: 2) {
            moreButton.tap()
            let destination = app.tables.cells.staticTexts.matching(predicate).firstMatch
            XCTAssertTrue(destination.waitForExistence(timeout: 5), "Missing overflow destination '\(expectedLabel)'. Tab labels: [\(labels)]")
            destination.tap()
            return
        }

        XCTFail("Unable to find tab '\(expectedLabel)'. Tab labels: [\(labels)]")
    }

    private func clearAndType(text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.typeText(text)
    }

    private func dismissKeyboardIfVisible() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let dismissalKeys = ["Done", "Return", "Go", "Search"]
        for key in dismissalKeys {
            let button = keyboard.buttons[key]
            if button.exists {
                button.tap()
                return
            }
        }
    }

    private func assertRewardsRefreshOutcomeAppeared() {
        let errorText = element(withID: "rewards.wallet.errorText")
        let addToWalletButton = app.buttons["rewards.wallet.addToWalletButton"]
        let notEnrolledText = element(withID: "rewards.wallet.notEnrolledText")
        let noDataText = element(withID: "rewards.wallet.noDataText")

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if errorText.exists || addToWalletButton.exists || notEnrolledText.exists || noDataText.exists {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        XCTFail("No rewards refresh outcome surfaced (expected error text or wallet/enrollment state).")
    }

    private func waitForElementByScrollingToVisible(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let tablesQuery = app.tables
        let firstTable = tablesQuery.firstMatch

        while Date() < deadline {
            if element.exists {
                return true
            }

            if firstTable.exists {
                firstTable.swipeUp()
            } else {
                app.swipeUp()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return element.exists
    }

    private func element(withID identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
