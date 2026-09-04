import Foundation

/// Turns spoken punctuation/formatting commands ("open quote", "comma", "new paragraph") into
/// the actual characters, and resolves "scratch" delete commands, the way real dictation
/// software does. This matches on the words themselves wherever they appear, so a sentence
/// that genuinely contains one of these phrases (e.g. "I need a comma before this") will also
/// get converted — an inherent tradeoff of voice-command punctuation, not something a phrase
/// list can fully avoid.
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

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
    ]

    static func apply(to text: String, scratchThatWordLimit: Int) -> String {
        let punctuated = applyPunctuationCommands(to: text)
        return resolveScratchCommands(in: punctuated, scratchThatWordLimit: scratchThatWordLimit)
    }

    private static func applyPunctuationCommands(to text: String) -> String {
        var result = text
        for command in commands {
            var pattern = #"\b(?:"# + command.pattern + #")\b"#
            // Whisper adds its own punctuation based on the pause after saying a command
            // phrase (e.g. "open quote" often comes through as "open quote. ") — absorb any
            // stray period/comma sitting right next to the command along with the space,
            // not just the space, or it leaks through as a spurious "." or ",".
            if command.consumeLeadingSpace { pattern = #"[\s.,]*"# + pattern }
            if command.consumeTrailingSpace { pattern += #"[\s.,]*"# }
            result = result.replacingOccurrences(of: pattern, with: command.replacement, options: [.regularExpression, .caseInsensitive])
        }
        return result
    }

    /// "scratch that" removes the last sentence (capped at scratchThatWordLimit words if it's
    /// longer than that); "scratch last <n>" (or "scratch last one") removes exactly n words.
    /// Rather than splitting on whitespace and rejoining with plain spaces (which would flatten
    /// any "\n\n" paragraph breaks back into spaces), each word keeps its own original leading
    /// whitespace so removing words never disturbs the spacing/newlines around what's left —
    /// the result then goes through TextDeliveryService's existing diff/backspace mechanism
    /// unchanged, the same as if the scratched words had never been said.
    private static func resolveScratchCommands(in text: String, scratchThatWordLimit: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\s*)(\S+)"#) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        let leadingWhitespace = matches.map { nsText.substring(with: $0.range(at: 1)) }
        let words = matches.map { nsText.substring(with: $0.range(at: 2)) }

        var toRemove = Set<Int>()
        var index = 0
        while index < words.count {
            guard normalized(words[index]) == "scratch" else {
                index += 1
                continue
            }

            if index + 1 < words.count, normalized(words[index + 1]) == "that" {
                let wordsToRemove = sentenceWordCount(before: index, in: words, cap: scratchThatWordLimit)
                let removeStart = max(0, index - wordsToRemove)
                for i in removeStart...(index + 1) { toRemove.insert(i) }
                index += 2
                continue
            }

            if index + 2 < words.count, normalized(words[index + 1]) == "last" {
                let countWord = normalized(words[index + 2])
                if let count = numberWords[countWord] ?? Int(countWord), count > 0 {
                    let removeStart = max(0, index - count)
                    for i in removeStart...(index + 2) { toRemove.insert(i) }
                    index += 3
                    continue
                }
            }

            index += 1
        }

        guard !toRemove.isEmpty else { return text }

        var result = ""
        for i in 0..<words.count where !toRemove.contains(i) {
            result += leadingWhitespace[i] + words[i]
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// Counts words backward from just before `index` until a sentence-ending token (one
    /// ending in ./!/?) or the cap is hit. A token that ends a sentence belongs to the
    /// *previous* sentence, so it's excluded from the count.
    private static func sentenceWordCount(before index: Int, in words: [String], cap: Int) -> Int {
        var count = 0
        var i = index - 1
        while i >= 0 {
            if words[i].hasSuffix(".") || words[i].hasSuffix("!") || words[i].hasSuffix("?") {
                break
            }
            count += 1
            if count >= cap { break }
            i -= 1
        }
        return count
    }
}
