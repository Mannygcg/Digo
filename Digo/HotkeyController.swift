import KeyboardShortcuts

final class HotkeyController {
    init(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation, action: onToggle)
    }
}
