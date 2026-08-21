import AppKit
import SwiftUI

/// Manages its own NSWindow rather than relying on SwiftUI's `Settings` scene — for an
/// LSUIElement (accessory, no Dock icon) app, the usual `showSettingsWindow:` trick posted
/// via NSApp.sendAction can silently fail to find a responder, since that action is normally
/// installed on the standard app menu, which accessory apps don't reliably get.
final class SettingsWindowController {
    private var window: NSWindow?
    private let dictationController: DictationController

    init(dictationController: DictationController) {
        self.dictationController = dictationController
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(dictationController: dictationController))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Digo Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}
