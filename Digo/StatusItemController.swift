import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let toggleItem: NSMenuItem
    private let engineMenuItems: [TranscriptionEngineKind: NSMenuItem]
    private let dictationController: DictationController

    init(dictationController: DictationController) {
        self.dictationController = dictationController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")

        var engineMenuItems: [TranscriptionEngineKind: NSMenuItem] = [:]
        for kind in TranscriptionEngineKind.allCases {
            engineMenuItems[kind] = NSMenuItem(title: kind.displayName, action: #selector(selectEngine(_:)), keyEquivalent: "")
        }
        self.engineMenuItems = engineMenuItems

        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Digo")

        let engineMenu = NSMenu()
        for kind in TranscriptionEngineKind.allCases {
            guard let item = engineMenuItems[kind] else { continue }
            item.target = self
            item.representedObject = kind
            engineMenu.addItem(item)
        }
        let engineMenuItem = NSMenuItem(title: "Engine", action: nil, keyEquivalent: "")
        engineMenuItem.submenu = engineMenu

        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(engineMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Digo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        updateEngineCheckmarks()
    }

    @objc private func toggleDictation() {
        dictationController.toggle()
    }

    @objc private func selectEngine(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? TranscriptionEngineKind else { return }
        dictationController.selectedEngineKind = kind
        updateEngineCheckmarks()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func updateUI(for state: DictationState) {
        switch state {
        case .idle:
            toggleItem.title = "Start Dictation"
            statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Digo")
        case .listening:
            toggleItem.title = "Stop Dictation"
            statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Digo (listening)")
        }
    }

    private func updateEngineCheckmarks() {
        let selected = dictationController.selectedEngineKind
        for (kind, item) in engineMenuItems {
            item.state = kind == selected ? .on : .off
        }
    }
}
