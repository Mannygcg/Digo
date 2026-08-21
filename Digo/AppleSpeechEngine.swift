import Speech
import AVFoundation

final class AppleSpeechEngine: TranscriptionEngine {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastPartialText = ""

    func startStreaming(onPartial: @escaping (String) -> Void,
                         onFinal: @escaping (String) -> Void,
                         onError: @escaping (Error) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionEngineError.recognizerUnavailable
        }

        lastPartialText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                onError(error)
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                // endAudio() sometimes delivers an empty isFinal result even though
                // the preceding partial already had the full utterance — fall back to it.
                onFinal(text.isEmpty ? (self?.lastPartialText ?? "") : text)
            } else {
                self?.lastPartialText = text
                onPartial(text)
            }
        }
    }

    func appendAudio(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stopStreaming() {
        // endAudio (not cancel) lets the task finish processing buffered audio
        // and deliver its isFinal result through the callback already in flight.
        request?.endAudio()
        request = nil
        task = nil
    }
}
