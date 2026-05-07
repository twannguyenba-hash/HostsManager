import SwiftUI

@main
struct HostsManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var hostsManager = HostsFileManager()
    @State private var envManager = EnvFileManager()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Active profile for the menu bar status item title (color dot + name).
    private var activeProfile: Profile? {
        guard let id = hostsManager.activeProfileID else { return nil }
        return hostsManager.profiles.first { $0.id == id }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(hostsManager)
                .environment(envManager)
                .frame(minWidth: 880, minHeight: 540)
        }
        // NOTE: do NOT use .windowStyle(.hiddenTitleBar) — that strips .titled from
        // the styleMask, which removes traffic lights AND prevents .fullSizeContentView
        // from taking effect (resulting in an empty bar above our custom TitleBar).
        // Instead, AppDelegate.configureWindows() makes the standard title bar
        // transparent so our gradient extends to the top with traffic lights overlaid.
        .windowResizability(.contentSize)
        .defaultSize(width: 980, height: 640)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Hoàn tác") { hostsManager.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!hostsManager.canUndo)
                Button("Làm lại") { hostsManager.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!hostsManager.canRedo)
            }
            CommandGroup(after: .textEditing) {
                Button("Tìm kiếm") {
                    hostsManager.isSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("Profile") {
                profileShortcutCommands
                Divider()
                Button("Bỏ chọn profile") {
                    hostsManager.switchProfile(to: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(hostsManager)
                .environment(envManager)
        }

        // Menu bar quick switch — togglable via Settings.
        // Title shows active profile color dot + name (or generic icon if none active).
        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarContentView()
                .environment(hostsManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    /// Status bar label — colored dot + active profile name when set, otherwise a
    /// generic globe icon. Re-renders when activeProfileID changes via SwiftUI.
    @ViewBuilder
    private var menuBarLabel: some View {
        if let profile = activeProfile {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.ds(profile.color))
                    .frame(width: 8, height: 8)
                Text(profile.name)
                    .font(.system(size: 12))
            }
        } else {
            Image(systemName: "globe")
        }
    }

    /// One menu item per profile (⌘1..⌘9). Hidden in production menu via empty title? — kept visible
    /// so users can discover the shortcut. macOS folds it into the Profile menu.
    @ViewBuilder
    private var profileShortcutCommands: some View {
        ForEach(hostsManager.profiles, id: \.id) { profile in
            if let n = profile.shortcutNumber, (1...9).contains(n) {
                Button("Switch to \(profile.name)") {
                    hostsManager.switchProfile(to: profile.id)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI creates the window after didFinishLaunching, so defer + observe.
        configureWindows()
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in self.configureWindows() }
    }

    /// Make the standard title bar transparent so our custom TitleBarView's gradient
    /// extends to the top of the window with traffic lights overlaid on it.
    /// Standard title bar = .titled style preserved → traffic lights visible.
    /// Skips NSPanel (MenuBarExtra) which doesn't need this treatment.
    private func configureWindows() {
        for window in NSApp.windows {
            if window is NSPanel { continue }
            guard window.styleMask.contains(.titled) else { continue }

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseAuthorization()
    }
}
