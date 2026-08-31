import AppKit
import os

final class TextDeliveryService {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "TextDeliveryService")
    private static let backspaceKeyCode: CGKeyCode = 0x33
    private static let returnKeyCode: CGKeyCode = 0x24
    /// Gap between synthetic keystrokes. JS-driven editors (Google Docs' canvas renderer, in
    /// particular) process input through their own event loop and can lose sync — dropping,
    /// reordering, or misplacing characters — when a burst of keystrokes arrives with no pacing
    /// at all, the way a single instant CGEvent-per-correction did before.
    private static let interKeystrokeDelay: useconds_t = 3_000

    /// All state access and event posting happens serially on this queue, off the main thread —
    /// pacing keystrokes here would otherwise block the UI for the duration of every correction.
    private let queue = DispatchQueue(label: "com.manuelcabrera.Digo.TextDeliveryService")

    /// On-screen text for the current live, still-correctable phrase (not yet committed).
    private var typedPhraseText = ""
    private var pendingSpaceNeeded = false

    func beginLiveSession() {
        queue.async {
            self.typedPhraseText = ""
            self.pendingSpaceNeeded = false
        }
    }

    func updateLive(_ text: String) {
        queue.async {
            guard PermissionsManager.isAccessibilityTrusted(), !text.isEmpty, text != self.typedPhraseText else { return }

            if Self.isLikelyNewPhrase(previous: self.typedPhraseText, incoming: text) {
                self.commitCurrentPhrase()
            }
            self.replaceTypedPhrase(with: text)
        }
    }

    func finishLiveSession(with text: String) {
        queue.async {
            guard PermissionsManager.isAccessibilityTrusted() else {
                Self.logger.debug("Accessibility not trusted — copying final text to clipboard only")
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                return
            }
            if !text.isEmpty {
                if Self.isLikelyNewPhrase(previous: self.typedPhraseText, incoming: text) {
                    self.commitCurrentPhrase()
                }
                self.replaceTypedPhrase(with: text)
            }
            self.typedPhraseText = ""
        }
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
            usleep(Self.interKeystrokeDelay)
        }
    }

    /// Posts one real keystroke per character (rather than one CGEvent carrying the whole
    /// string) so the receiving app sees the same event pattern a real keyboard would produce.
    /// Newlines specifically need to be a real Return keypress (its own virtual keycode) —
    /// typing "\n" as Unicode text doesn't reliably trigger the same behavior most apps expect
    /// from an actual Return press. Shift+Return rather than a plain Return, since many text
    /// fields (chat boxes, search fields, message inputs) treat a plain Return as "submit" —
    /// Shift+Return is the standard "insert a line break, don't submit" convention.
    private func typeText(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        for character in text {
            if character == "\n" {
                let down = CGEvent(keyboardEventSource: source, virtualKey: Self.returnKeyCode, keyDown: true)
                let up = CGEvent(keyboardEventSource: source, virtualKey: Self.returnKeyCode, keyDown: false)
                down?.flags = .maskShift
                up?.flags = .maskShift
                down?.post(tap: .cghidEventTap)
                up?.post(tap: .cghidEventTap)
                usleep(Self.interKeystrokeDelay)
                continue
            }
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            let utf16 = Array(String(character).utf16)
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            usleep(Self.interKeystrokeDelay)
        }
    }
}
