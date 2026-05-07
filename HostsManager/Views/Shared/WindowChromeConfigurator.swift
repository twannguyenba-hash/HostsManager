import AppKit
import SwiftUI

/// Reaches up to the hosting NSWindow once it exists and applies our custom chrome:
/// transparent title bar, full-size content view, traffic lights overlaid on our
/// TitleBarView gradient. This must run from inside the SwiftUI view tree (not
/// AppDelegate) because NSApp.windows iteration at didFinishLaunching can miss
/// the WindowGroup window — viewDidMoveToWindow is the reliable hook.
struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ProbeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Apply our custom chrome to `window`. Exposed for tests.
    static func configure(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        // CRITICAL (macOS SDK 26): when titlebarAppearsTransparent + fullSizeContentView
        // are both set, NSTitlebarContainerView gets isHidden=true / alpha=0 by the
        // system, hiding the traffic lights. Force the container visible.
        let close = window.standardWindowButton(.closeButton)
        if let titlebarContainer = close?.superview?.superview {
            titlebarContainer.isHidden = false
            titlebarContainer.alphaValue = 1.0
        }
        close?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }

    private final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = self.window, !(window is NSPanel) else { return }
            WindowChromeConfigurator.configure(window)
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                guard let window else { return }
                WindowChromeConfigurator.configure(window)
            }
        }
    }
}
