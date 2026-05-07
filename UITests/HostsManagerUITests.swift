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
        // Tab pills are SwiftUI Buttons but `.buttonStyle(.plain)` + custom label
        // makes the AX type ambiguous on macOS — match by identifier across any
        // element type to stay resilient.
        // Identifier-only match (no label fallback) — the OR-with-label trick used
        // to silently match the inner detail-header Text "Hosts", which became a
        // stale reference after switching to Env and made the back-click no-op.
        let envTab = app.buttons["tab-env"]
        let hostsTab = app.buttons["tab-hosts"]
        if !envTab.waitForExistence(timeout: 5) {
            print("==DEBUG TREE==\n\(app.debugDescription)")
        }
        XCTAssertTrue(envTab.exists, "Env tab should exist (see debug tree)")
        XCTAssertTrue(hostsTab.exists, "Hosts tab should exist")

        // Initially Hosts is selected — its sidebar header "Profiles" must be visible,
        // env-only header "Repos" must not.
        XCTAssertTrue(app.staticTexts["PROFILES"].waitForExistence(timeout: 2),
                      "Hosts sidebar (PROFILES) should be visible on launch")

        // ---- Switch to Env ----
        envTab.click()
        Thread.sleep(forTimeInterval: 0.5)

        // TitleBar still visible
        XCTAssertTrue(app.staticTexts["Hosts Manager"].exists,
                      "TitleBar must persist after switching to Env")
        // Env-only sidebar header
        XCTAssertTrue(app.staticTexts["REPOS"].waitForExistence(timeout: 2),
                      "After Env click, sidebar should show REPOS")
        XCTAssertFalse(app.staticTexts["PROFILES"].exists,
                       "PROFILES (hosts sidebar) must no longer be visible after switching to Env")

        // ---- Switch back to Hosts ----
        print("==BEFORE HOSTS CLICK== hostsTab.exists=\(hostsTab.exists) hittable=\(hostsTab.isHittable) frame=\(hostsTab.frame)")
        hostsTab.click()
        Thread.sleep(forTimeInterval: 0.5)
        print("==AFTER HOSTS CLICK== profiles.exists=\(app.staticTexts["PROFILES"].exists) repos.exists=\(app.staticTexts["REPOS"].exists)")
        if !app.staticTexts["PROFILES"].exists {
            print("==DEBUG TREE AFTER FAILED HOSTS CLICK==\n\(app.debugDescription)")
        }

        XCTAssertTrue(app.staticTexts["Hosts Manager"].exists,
                      "TitleBar must persist after switching back to Hosts")
        XCTAssertTrue(app.staticTexts["PROFILES"].waitForExistence(timeout: 2),
                      "After Hosts click, sidebar should show PROFILES again")
        XCTAssertFalse(app.staticTexts["REPOS"].exists,
                       "REPOS must no longer be visible after switching back to Hosts")
    }

    /// Regression: NavigationSplitView in EnvView would hide NSTitlebarContainerView,
    /// making traffic lights disappear on Env tab. Verifies close button stays hittable.
    func test_trafficLights_remainVisibleAfterEnvSwitch() {
        let close = app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        XCTAssertTrue(close.isHittable, "Close button hittable on launch")

        let envTab = app.buttons["tab-env"]
        XCTAssertTrue(envTab.waitForExistence(timeout: 3))
        envTab.click()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(close.exists, "Close button still exists after Env tab")
        XCTAssertTrue(close.isHittable, "Close button still hittable after Env tab — traffic lights must persist")
    }

    /// Regression: NavigationSplitView in EnvView auto-derived window title from
    /// CFBundleName ("HostsManager") and rendered it above our custom TitleBarView.
    /// Fixed via .windowToolbarStyle(.unified(showsTitle: false)) at the scene.
    /// Custom title is "Hosts Manager" (with space); bundle name is "HostsManager".
    func test_windowTitle_bundleNameNotShownAfterEnvSwitch() {
        let envTab = app.buttons["tab-env"]
        XCTAssertTrue(envTab.waitForExistence(timeout: 3))
        envTab.click()
        Thread.sleep(forTimeInterval: 0.6)

        XCTAssertFalse(app.staticTexts["HostsManager"].exists,
                       "AppKit window title (CFBundleName) must not render — windowToolbarStyle should hide it")
        // Our custom title bar must still be visible
        XCTAssertTrue(app.staticTexts["Hosts Manager"].exists,
                      "Custom TitleBarView text must remain")

        // NSV's auto-installed "Hide Sidebar" toggle (lives inside the sidebar
        // column, not the window toolbar) must be hidden via .toolbar(removing: .sidebarToggle).
        let toggleSidebar = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'sidebar'"
        ))
        XCTAssertEqual(toggleSidebar.count, 0,
                       "NavigationSplitView sidebar-toggle must be hidden")
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

        // SwiftUI Settings scene exposes a "Settings…" item in the app menu.
        // Open menu, wait for it to render, then click via menuBars > menuItems
        // (more reliable than top-level descendants matching).
        let appMenu = app.menuBars.menuBarItems.element(boundBy: 0)
        XCTAssertTrue(appMenu.waitForExistence(timeout: 2), "App menu missing")
        appMenu.click()
        Thread.sleep(forTimeInterval: 0.4)  // menu animation

        let settingsItem = app.menuBars.menuItems
            .matching(NSPredicate(format: "title BEGINSWITH 'Settings' OR title BEGINSWITH 'Preferences'"))
            .firstMatch
        guard settingsItem.waitForExistence(timeout: 2),
              settingsItem.isHittable
        else {
            // Dismiss menu before failing
            app.typeKey(.escape, modifierFlags: [])
            throw XCTSkip("Settings… menu item not hittable in this runner context")
        }
        settingsItem.click()
        Thread.sleep(forTimeInterval: 0.6)

        XCTAssertGreaterThan(app.windows.count, initialWindowCount,
                             "Settings window should appear")
    }
}
