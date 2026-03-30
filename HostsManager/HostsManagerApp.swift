import SwiftUI

@main
struct HostsManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var hostsManager = HostsFileManager()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hostsManager)
                .frame(minWidth: 800, minHeight: 500)
                .navigationTitle("Hosts Manager v\(appVersion)")
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
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
