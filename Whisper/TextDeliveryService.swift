import AppKit
import os

final class TextDeliveryService {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Whisper", category: "TextDeliveryService")
    private static let backspaceKeyCode: CGKeyCode = 0x33

    /// On-screen text for the current live, still-correctable phrase (not yet committed).
    private var typedPhraseText = ""
    private var pendingSpaceNeeded = false

    func beginLiveSession() {
        typedPhraseText = ""
        pendingSpaceNeeded = false
    }

    func updateLive(_ text: String) {
        guard PermissionsManager.isAccessibilityTrusted(), !text.isEmpty, text != typedPhraseText else { return }

        if Self.isLikelyNewPhrase(previous: typedPhraseText, incoming: text) {
            commitCurrentPhrase()
        }
        replaceTypedPhrase(with: text)
    }

    func finishLiveSession(with text: String) {
        guard PermissionsManager.isAccessibilityTrusted() else {
            Self.logger.debug("Accessibility not trusted — copying final text to clipboard only")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return
        }
        if !text.isEmpty {
            if Self.isLikelyNewPhrase(previous: typedPhraseText, incoming: text) {
                commitCurrentPhrase()
            }
            replaceTypedPhrase(with: text)
        }
        typedPhraseText = ""
    }

    /// The on-device recognizer periodically finalizes its internal transcript after a pause
    /// and starts a fresh one — surfacing as a much shorter partial replacing a long one. Treat
    /// that as a new phrase to append rather than a correction that should erase existing text.
    private static func isLikelyNewPhrase(previous: String, incoming: String) -> Bool {
        guard previous.count > 8 else { return false }
        return incoming.count < previous.count / 2
    }

    private func commitCurrentPhrase() {
        guard !typedPhraseText.isEmpty else { return }
        typedPhraseText = ""
        pendingSpaceNeeded = true
    }

    private func replaceTypedPhrase(with newText: String) {
        if pendingSpaceNeeded {
            typeText(" ")
            pendingSpaceNeeded = false
        }

        let common = Self.commonPrefixLength(typedPhraseText, newText)
        let deleteCount = typedPhraseText.count - common
        if deleteCount > 0 {
            sendBackspaces(deleteCount)
        }
        let toType = String(newText.dropFirst(common))
        if !toType.isEmpty {
            typeText(toType)
        }
        typedPhraseText = newText
    }

    private static func commonPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (charA, charB) in zip(a, b) {
            guard charA == charB else { break }
            count += 1
        }
        return count
    }

    private func sendBackspaces(_ count: Int) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: Self.backspaceKeyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: Self.backspaceKeyCode, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func typeText(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }

        let utf16 = Array(text.utf16)
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
