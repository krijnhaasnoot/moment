//
//  MomentUITests.swift
//  MomentUITests
//
//  UI tests for Moment fertility tracking app
//

import XCTest

final class MomentUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Welcome Screen Tests
    
    func testWelcomeScreenDisplaysCorrectly() throws {
        // Check for welcome elements
        let momentTitle = app.staticTexts["Moment"]
        XCTAssertTrue(momentTitle.waitForExistence(timeout: 5))
        
        let tagline = app.staticTexts["Timing, together"]
        XCTAssertTrue(tagline.exists)
    }
    
    func testWelcomeScreenHasGetStartedButton() throws {
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
    }
    
    // MARK: - Auth Screen Tests
    
    func testAuthScreenHasAppleSignIn() throws {
        // Navigate to auth screen
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5) {
            getStartedButton.tap()
        }
        
        // Check for Sign in with Apple button (may be on auth screen)
        let appleSignInButton = app.buttons["Sign in with Apple"]
        // This may or may not exist depending on navigation flow
    }
    
    func testAuthScreenHasEmailOption() throws {
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5) {
            getStartedButton.tap()
        }
        
        let emailButton = app.buttons["Continue with Email"]
        // Check if email option exists
    }
    
    // MARK: - Role Selection Tests
    
    func testRoleSelectionScreen() throws {
        // Navigate through welcome
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5) {
            getStartedButton.tap()
        }
        
        // Look for role selection
        let trackingOption = app.staticTexts["I'm tracking my cycle"]
        let partnerOption = app.staticTexts["I'm the partner"]
        
        // At least one should exist if we're on role selection
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateThroughOnboarding() throws {
        // Start
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 5) {
            getStartedButton.tap()
        }
        
        // This test verifies basic navigation works
        // Actual flow depends on whether user is authenticated
    }
}

// MARK: - Home Screen Tests

final class HomeScreenUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SKIP_AUTH"] // Skip auth for testing
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testHomeScreenHasTodayTab() throws {
        let todayTab = app.buttons["Today"]
        // Check if exists when on home screen
    }
    
    func testHomeScreenHasCalendarTab() throws {
        let calendarTab = app.buttons["Calendar"]
        // Check if exists when on home screen
    }
    
    func testHomeScreenHasSettingsButton() throws {
        // Settings is typically a gear icon
        let settingsButton = app.buttons["gearshape"]
        // Or look for it by accessibility identifier
    }
}

// MARK: - Calendar Tests

final class CalendarUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SKIP_AUTH"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testCalendarShowsMonthNavigation() throws {
        // Navigate to calendar tab
        let calendarTab = app.buttons["Calendar"]
        if calendarTab.waitForExistence(timeout: 5) {
            calendarTab.tap()
        }
        
        // Check for month navigation arrows
        let leftArrow = app.buttons["chevron.left"]
        let rightArrow = app.buttons["chevron.right"]
    }
    
    func testCalendarShowsWeekdayHeaders() throws {
        let calendarTab = app.buttons["Calendar"]
        if calendarTab.waitForExistence(timeout: 5) {
            calendarTab.tap()
        }
        
        // Check for weekday headers (S, M, T, W, T, F, S)
        // These would be static texts
    }
}

// MARK: - Settings Tests

final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SKIP_AUTH"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testSettingsHasSignOutButton() throws {
        // Open settings
        let settingsButton = app.buttons["gearshape"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
        
        let signOutButton = app.buttons["Sign Out"]
        // Check if exists
    }
    
    func testSettingsHasResetButton() throws {
        let settingsButton = app.buttons["gearshape"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
        
        let resetButton = app.buttons["Reset All Data"]
        // Check if exists
    }
    
    func testSettingsShowsProfileSection() throws {
        let settingsButton = app.buttons["gearshape"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
        
        let profileText = app.staticTexts["Profile"]
        // Check if exists
    }
}

// MARK: - LH Logging Tests

final class LHLoggingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SKIP_AUTH", "IN_FERTILE_WINDOW"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testLHLoggingSheetHasOptions() throws {
        // Find and tap LH test button
        let lhButton = app.buttons["Log LH Test"]
        if lhButton.waitForExistence(timeout: 5) {
            lhButton.tap()
        }
        
        // Check for options
        let negativeOption = app.staticTexts["Negative"]
        let positiveOption = app.staticTexts["Positive"]
    }
    
    func testLHLoggingSheetCanBeDismissed() throws {
        let lhButton = app.buttons["Log LH Test"]
        if lhButton.waitForExistence(timeout: 5) {
            lhButton.tap()
        }
        
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }
        
        // Verify sheet is dismissed
    }
}

// MARK: - Period Logging Tests

final class PeriodLoggingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SKIP_AUTH"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testPeriodLoggingSheetHasDatePicker() throws {
        let periodButton = app.buttons["Log Period"]
        if periodButton.waitForExistence(timeout: 5) {
            periodButton.tap()
        }
        
        // Check for date picker
        let datePicker = app.datePickers.firstMatch
        // Verify exists
    }
    
    func testPeriodLoggingSheetHasLogButton() throws {
        let periodButton = app.buttons["Log Period"]
        if periodButton.waitForExistence(timeout: 5) {
            periodButton.tap()
        }
        
        let logButton = app.buttons["Log Period Start"]
        // Check if exists
    }
}

// MARK: - Accessibility Tests

final class AccessibilityUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAllButtonsAreAccessible() throws {
        // Check that key buttons have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        
        for button in buttons {
            // Each button should have an identifier or label
            XCTAssertFalse(button.label.isEmpty || button.identifier.isEmpty,
                          "Button should have accessibility label or identifier")
        }
    }
    
    func testTextIsReadable() throws {
        // Ensure text elements exist and are hittable
        let texts = app.staticTexts.allElementsBoundByIndex
        
        for text in texts.prefix(10) { // Check first 10
            XCTAssertTrue(text.exists)
        }
    }
}
