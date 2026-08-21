import SwiftUI

@main
struct DigoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings is shown via SettingsWindowController (AppKit-managed), not this scene —
        // see SettingsWindowController.swift for why. This just satisfies the App protocol.
        Settings {
            EmptyView()
        }
    }
}
