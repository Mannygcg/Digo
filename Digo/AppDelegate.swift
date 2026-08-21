import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "AppDelegate")

    private var statusItemController: StatusItemController?
    private(set) var dictationController: DictationController?
    private var hotkeyController: HotkeyController?
    private var hudWindowController: HUDWindowController?
    private var settingsWindowController: SettingsWindowController?
    private let textDeliveryService = TextDeliveryService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsManager.isAccessibilityTrusted() {
            PermissionsManager.requestAccessibilityAccess()
        }

        let dictationController = DictationController()
        self.dictationController = dictationController

        let settingsWindowController = SettingsWindowController(dictationController: dictationController)
        self.settingsWindowController = settingsWindowController

        let statusItemController = StatusItemController(
            dictationController: dictationController,
            onOpenSettings: { settingsWindowController.show() }
        )
        self.statusItemController = statusItemController

        let hudWindowController = HUDWindowController()
        self.hudWindowController = hudWindowController

        hotkeyController = HotkeyController(onToggle: dictationController.toggle)

        dictationController.onStateChange = { [weak self, weak statusItemController, weak hudWindowController] state in
            statusItemController?.updateUI(for: state)
            switch state {
            case .listening:
                hudWindowController?.show()
                self?.textDeliveryService.beginLiveSession()
            case .transcribing:
                hudWindowController?.update(text: "Refining…")
            case .idle:
                break
            }
        }
        dictationController.onPartialTranscript = { [weak self, weak hudWindowController] text in
            hudWindowController?.update(text: text)
            self?.textDeliveryService.updateLive(text)
        }
        dictationController.onFinalTranscript = { [weak self, weak hudWindowController] text in
            Self.logger.debug("Final transcript: \(text, privacy: .public)")
            self?.textDeliveryService.finishLiveSession(with: text)
            hudWindowController?.update(text: "Ready!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                hudWindowController?.hide()
            }
        }
        dictationController.onEngineError = { [weak hudWindowController] _ in
            hudWindowController?.hide()
        }
    }
}
