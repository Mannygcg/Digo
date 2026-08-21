import Foundation

enum TranscriptionEngineKind: String, CaseIterable {
    case appleSpeech
    case whisperKit

    var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech (on-device)"
        case .whisperKit: return "Whisper (local model)"
        }
    }
}
