import Testing
import AppKit
@testable import HostsManager

@Suite("WindowChromeConfigurator")
@MainActor
struct WindowChromeConfiguratorTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
    }

    @Test("Sets all required style mask flags")
    func styleMaskHasAllFlags() {
        let w = makeWindow()
        WindowChromeConfigurator.configure(w)
        #expect(w.styleMask.contains(.titled))
        #expect(w.styleMask.contains(.closable))
        #expect(w.styleMask.contains(.miniaturizable))
        #expect(w.styleMask.contains(.resizable))
        #expect(w.styleMask.contains(.fullSizeContentView))
    }

    @Test("Makes title bar transparent and hides title text")
    func titleBarTransparentAndHidden() {
        let w = makeWindow()
        WindowChromeConfigurator.configure(w)
        #expect(w.titlebarAppearsTransparent == true)
        #expect(w.titleVisibility == .hidden)
        #expect(w.isMovableByWindowBackground == true)
        #expect(w.toolbar == nil)
    }

    @Test("Standard window buttons are not hidden after configure")
    func standardButtonsNotHidden() {
        let w = makeWindow()
        WindowChromeConfigurator.configure(w)
        #expect(w.standardWindowButton(.closeButton)?.isHidden == false)
        #expect(w.standardWindowButton(.miniaturizeButton)?.isHidden == false)
        #expect(w.standardWindowButton(.zoomButton)?.isHidden == false)
    }

    @Test("NSTitlebarContainerView (button parent's parent) is visible after configure")
    func titlebarContainerVisible() {
        let w = makeWindow()
        // Force the system to set up the hidden state by enabling transparent + fullsize
        // BEFORE configure runs (mimics the system pre-condition triggering the bug).
        w.titlebarAppearsTransparent = true
        w.styleMask.insert(.fullSizeContentView)
        if let container = w.standardWindowButton(.closeButton)?.superview?.superview {
            container.isHidden = true
            container.alphaValue = 0.0
        }

        WindowChromeConfigurator.configure(w)

        let container = w.standardWindowButton(.closeButton)?.superview?.superview
        #expect(container?.isHidden == false)
        #expect(container?.alphaValue == 1.0)
    }

    @Test("Re-applying is idempotent (multiple calls do not regress state)")
    func reapplyIsIdempotent() {
        let w = makeWindow()
        WindowChromeConfigurator.configure(w)
        WindowChromeConfigurator.configure(w)
        WindowChromeConfigurator.configure(w)
        #expect(w.styleMask.contains(.fullSizeContentView))
        #expect(w.titlebarAppearsTransparent == true)
        #expect(w.standardWindowButton(.closeButton)?.isHidden == false)
    }
}
