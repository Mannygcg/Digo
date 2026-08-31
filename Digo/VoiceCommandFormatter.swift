import Foundation

/// Turns spoken punctuation/formatting commands ("open quote", "comma", "new line") into the
/// actual characters, the way real dictation software does. This matches on the words
/// themselves wherever they appear, so a sentence that genuinely contains one of these phrases
/// (e.g. "I need a comma before this") will also get converted — an inherent tradeoff of
/// voice-command punctuation, not something a phrase list can fully avoid.
enum VoiceCommandFormatter {
    private struct Command {
        let pattern: String
        let replacement: String
        let consumeLeadingSpace: Bool
        let consumeTrailingSpace: Bool
    }

    private static let commands: [Command] = [
        Command(pattern: #"open quotes?"#, replacement: "\"", consumeLeadingSpace: false, consumeTrailingSpace: true),
        Command(pattern: #"close quotes?"#, replacement: "\"", consumeLeadingSpace: true, consumeTrailingSpace: false),
        Command(pattern: #"open parenthes(is|es)"#, replacement: "(", consumeLeadingSpace: false, consumeTrailingSpace: true),
        Command(pattern: #"close parenthes(is|es)"#, replacement: ")", consumeLeadingSpace: true, consumeTrailingSpace: false),
        Command(pattern: #"new paragraph"#, replacement: "\n\n", consumeLeadingSpace: true, consumeTrailingSpace: true),
        Command(pattern: #"comma"#, replacement: ",", consumeLeadingSpace: true, consumeTrailingSpace: false),
        Command(pattern: #"period|full stop"#, replacement: ".", consumeLeadingSpace: true, consumeTrailingSpace: false),
        Command(pattern: #"question mark"#, replacement: "?", consumeLeadingSpace: true, consumeTrailingSpace: false),
        Command(pattern: #"exclamation (point|mark)"#, replacement: "!", consumeLeadingSpace: true, consumeTrailingSpace: false),
    ]

    static func apply(to text: String) -> String {
        var result = text
        for command in commands {
            var pattern = #"\b(?:"# + command.pattern + #")\b"#
            if command.consumeLeadingSpace { pattern = #" ?"# + pattern }
            if command.consumeTrailingSpace { pattern += #" ?"# }
            result = result.replacingOccurrences(of: pattern, with: command.replacement, options: [.regularExpression, .caseInsensitive])
        }
        return result
    }
}
