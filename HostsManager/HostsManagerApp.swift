import SwiftUI

@main
struct HostsManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var hostsManager = HostsFileManager()
    @StateObject private var envManager = EnvFileManager()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hostsManager)
                .environmentObject(envManager)
                .frame(minWidth: 800, minHeight: 500)
                .navigationTitle("Hosts Manager v\(appVersion)")
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Tìm kiếm") {
                    hostsManager.isSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseAuthorization()
    }
}
