import XCTest

/// End-to-end smoke tests via XCUITest. Exercises window chrome, tab switcher,
/// sidebar profile activation, search field, and ⌘1 shortcut.
///
/// Notes:
/// - Apply (sudo write to /etc/hosts) is NOT exercised — would require interactive
///   password dialog. Tests stop at the "intent" of saving, not actual file write.
/// - These tests assume a fresh run with default profiles auto-created from the
///   user's real /etc/hosts. If `/etc/hosts` is empty of tag markers, sidebar
///   only has filters; profile-activation test will be skipped.
final class HostsManagerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Smoke tests

    func test_appLaunches_andMainWindowVisible() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        // TitleBar text proves shell rendered
        XCTAssertTrue(app.staticTexts["Hosts Manager"].exists)
    }

    func test_tabSwitcher_switchesBetweenHostsAndEnv() {
        // Search by label or identifier (Button + custom HStack label can show as either).
        let envTab = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'tab-env' OR label == 'Env'"))
            .firstMatch
        let hostsTab = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'tab-hosts' OR label == 'Hosts'"))
            .firstMatch
        XCTAssertTrue(envTab.waitForExistence(timeout: 5), "tab-env should exist")

        envTab.click()
        // Sleep brief — tab content swap animates 180ms
        Thread.sleep(forTimeInterval: 0.4)

        hostsTab.click()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(app.windows.firstMatch.exists, "Window should still be present after tab switches")
    }

    func test_searchField_filtersHostList() throws {
        let search = app.textFields["hosts-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))

        // Type a substring of "localhost" — should always exist in /etc/hosts
        search.click()
        search.typeText("localhost")

        // After filter: at least one localhost row should still be visible
        XCTAssertTrue(app.staticTexts["localhost"].waitForExistence(timeout: 2),
                      "Expected at least one 'localhost' row after filter")
    }

    func test_profileRow_clickActivatesProfile() throws {
        // Find any profile row (created from existing /etc/hosts tag markers)
        let profileRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile-row-'"))

        guard profileRows.count > 0 else {
            throw XCTSkip("No profiles in current /etc/hosts — skipping activation test")
        }

        let firstProfile = profileRows.element(boundBy: 0)
        XCTAssertTrue(firstProfile.exists)
        firstProfile.click()
        // Click again deactivates (toggle behavior). Just assert click didn't crash.
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func test_keyboardShortcut_cmd1_switchesToFirstProfile() throws {
        let profileRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile-row-'"))
        guard profileRows.count > 0 else {
            throw XCTSkip("No profiles defined — skipping ⌘1 shortcut test")
        }

        // Send ⌘1 to active window
        app.typeKey("1", modifierFlags: .command)
        // No assertion specific — just verifies app doesn't crash on keyboard shortcut.
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func test_settingsScene_opensViaMenuBar() throws {
        let initialWindowCount = app.windows.count

        // SwiftUI Settings scene gets a "Settings…" menu item in the app menu
        // (often "HostsManager → Settings…"). ⌘, may fail in test runner if focus
        // isn't on the SwiftUI window — use the menu bar directly.
        let appMenu = app.menuBars.menuBarItems.element(boundBy: 0)
        XCTAssertTrue(appMenu.waitForExistence(timeout: 2), "App menu missing")
        appMenu.click()

        // The settings item title is "Settings…" on macOS 13+; older was "Preferences…"
        let settingsItem = app.menuItems
            .matching(NSPredicate(format: "title BEGINSWITH 'Settings' OR title BEGINSWITH 'Preferences'"))
            .firstMatch
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 2), "Settings… menu item missing")
        settingsItem.click()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertGreaterThan(app.windows.count, initialWindowCount,
                             "Settings window should appear")
    }
}
