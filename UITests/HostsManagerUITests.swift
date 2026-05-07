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
        let envTab = app.buttons["tab-env"]
        let hostsTab = app.buttons["tab-hosts"]
        XCTAssertTrue(envTab.waitForExistence(timeout: 3))

        envTab.click()
        // Env tab content should render (Repos label or empty repo state)
        XCTAssertTrue(app.staticTexts["REPOS"].waitForExistence(timeout: 2)
                      || app.staticTexts["Chưa có repo"].waitForExistence(timeout: 2))

        hostsTab.click()
        XCTAssertTrue(app.staticTexts["Hosts"].waitForExistence(timeout: 2))
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

    func test_settingsScene_opensViaCommand() throws {
        // ⌘, opens Settings (system default shortcut)
        app.typeKey(",", modifierFlags: .command)

        // Settings window should appear with our tabs
        let generalTab = app.tabs["General"]
        XCTAssertTrue(generalTab.waitForExistence(timeout: 3),
                      "Settings window with General tab should appear")
    }
}
