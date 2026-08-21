import AppKit
import Combine

final class StatusItemController: NSObject {
    private static let icon: NSImage? = {
        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Digo"
        return image
    }()

    private let statusItem: NSStatusItem
    private let toggleItem: NSMenuItem
    private let engineMenu = NSMenu()
    private let recentMenu = NSMenu()
    private let dictationController: DictationController
    private let onOpenSettings: () -> Void
    private var cancellable: AnyCancellable?

    init(dictationController: DictationController, onOpenSettings: @escaping () -> Void) {
        self.dictationController = dictationController
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")

        super.init()

        statusItem.button?.image = Self.icon

        let recentMenuItem = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recentMenuItem.submenu = recentMenu

        let engineMenuItem = NSMenuItem(title: "Engine", action: nil, keyEquivalent: "")
        engineMenuItem.submenu = engineMenu

        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(recentMenuItem)
        menu.addItem(engineMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Digo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        rebuildEngineMenu()
        rebuildRecentMenu()

        // Keep the menus in sync when engines/transcripts change from outside this
        // controller — e.g. from the Settings window, or a new dictation finishing.
        cancellable = dictationController.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.rebuildEngineMenu()
                self?.rebuildRecentMenu()
            }
        }
    }

    @objc private func toggleDictation() {
        dictationController.toggle()
    }

    @objc private func selectEngine(_ sender: NSMenuItem) {
        guard let modelID = sender.representedObject as? String else { return }
        dictationController.selectedModelID = modelID
        rebuildEngineMenu()
    }

    @objc private func copyRecentTranscript(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    func updateUI(for state: DictationState) {
        toggleItem.isEnabled = state != .transcribing
        statusItem.button?.image = Self.icon
        switch state {
        case .idle:
            toggleItem.title = "Start Dictation"
        case .listening:
            toggleItem.title = "Stop Dictation"
        case .transcribing:
            toggleItem.title = "Transcribing…"
        }
    }

    private func rebuildEngineMenu() {
        let selected = dictationController.selectedModelID
        engineMenu.removeAllItems()
        for modelID in dictationController.enabledModelIDs {
            let item = NSMenuItem(title: WhisperModelCatalog.option(for: modelID)?.displayName ?? modelID,
                                   action: #selector(selectEngine(_:)),
                                   keyEquivalent: "")
            item.target = self
            item.representedObject = modelID
            item.state = modelID == selected ? .on : .off
            engineMenu.addItem(item)
        }
    }

    private func rebuildRecentMenu() {
        recentMenu.removeAllItems()
        let recents = dictationController.recentTranscripts
        if recents.isEmpty {
            let item = NSMenuItem(title: "No recent transcripts", action: nil, keyEquivalent: "")
            item.isEnabled = false
            recentMenu.addItem(item)
        } else {
            for text in recents {
                let preview = text.count > 60 ? String(text.prefix(60)) + "…" : text
                let item = NSMenuItem(title: preview, action: #selector(copyRecentTranscript(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = text
                recentMenu.addItem(item)
            }
        }
    }
}
