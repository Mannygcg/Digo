import Foundation

struct WhisperModelOption {
    /// WhisperKit model repo name, e.g. "openai_whisper-base".
    let id: String
    let displayName: String
    let note: String?
    /// Shipped enabled out of the box.
    let isDefault: Bool
}

/// The set of Whisper models a user can enable from the menu bar's "Add Engine" list.
/// Adding a new model to Digo is just adding an entry here.
enum WhisperModelCatalog {
    static let all: [WhisperModelOption] = [
        WhisperModelOption(
            id: "openai_whisper-tiny",
            displayName: "Whisper — Swift",
            note: "Fastest, least accurate. Included by default.",
            isDefault: true
        ),
        WhisperModelOption(
            id: "openai_whisper-base",
            displayName: "Whisper — Base",
            note: "Balanced speed and accuracy. Included by default.",
            isDefault: true
        ),
        WhisperModelOption(
            id: "openai_whisper-medium",
            displayName: "Whisper — Medium",
            note: "More accurate, but requires more computing power and is slower.",
            isDefault: false
        ),
        WhisperModelOption(
            id: "openai_whisper-large-v3",
            displayName: "Whisper — Large",
            note: "Most accurate, but requires significantly more computing power and is noticeably slower.",
            isDefault: false
        ),
    ]

    static let defaultSelection = "openai_whisper-base"

    static func option(for id: String) -> WhisperModelOption? {
        all.first { $0.id == id }
    }
}
