import Foundation
import WhisperKit
import os

enum WhisperKitEngineError: Error {
    case tokenizerUnavailable
}

/// Streams the microphone into WhisperKit's own realtime transcriber, which captures audio
/// itself via WhisperKit's AudioProcessor, so text appears continuously while the user talks,
/// instead of only after they stop.
final class WhisperKitEngine {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "WhisperKitEngine")

    private let modelName: String
    private let stateQueue = DispatchQueue(label: "com.manuelcabrera.Digo.WhisperKitEngine.state")

    private var loadTask: Task<WhisperKit, Error>?
    private var streamer: AudioStreamTranscriber?
    private var sessionID = 0
    private var latestText = ""
    private var onFinalHandler: ((String) -> Void)?

    init(modelName: String) {
        self.modelName = modelName
    }

    /// Kicks off (or reuses) the model load without blocking the caller — call as soon as
    /// this engine is selected so the model is likely ready by the time recording starts.
    func preload() {
        _ = loadedWhisperKit()
    }

    func startStreaming(onPartial: @escaping (String) -> Void,
                         onFinal: @escaping (String) -> Void,
                         onError: @escaping (Error) -> Void) throws {
        let session = stateQueue.sync { () -> Int in
            sessionID += 1
            latestText = ""
            return sessionID
        }
        onFinalHandler = onFinal

        Task {
            do {
                let kit = try await loadedWhisperKit().value
                guard let tokenizer = kit.tokenizer else {
                    throw WhisperKitEngineError.tokenizerUnavailable
                }
                guard stateQueue.sync(execute: { session == self.sessionID }) else { return }

                let decodingOptions = DecodingOptions(task: .transcribe, language: "en", skipSpecialTokens: true)
                let streamer = AudioStreamTranscriber(
                    audioEncoder: kit.audioEncoder,
                    featureExtractor: kit.featureExtractor,
                    segmentSeeker: kit.segmentSeeker,
                    textDecoder: kit.textDecoder,
                    tokenizer: tokenizer,
                    audioProcessor: kit.audioProcessor,
                    decodingOptions: decodingOptions
                ) { [weak self] _, newState in
                    guard let self, session == self.stateQueue.sync(execute: { self.sessionID }) else { return }
                    let text = (newState.confirmedSegments.map(\.text) + newState.unconfirmedSegments.map(\.text))
                        .joined()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    self.stateQueue.sync { self.latestText = text }
                    onPartial(text)
                }
                self.streamer = streamer

                // Re-check right before starting the mic: stop() may have landed while we were loading.
                guard stateQueue.sync(execute: { session == self.sessionID }) else { return }
                try await streamer.startStreamTranscription()
            } catch {
                guard stateQueue.sync(execute: { session == self.sessionID }) else { return }
                Self.logger.error("Whisper streaming failed: \(String(describing: error), privacy: .public)")
                onError(error)
            }
        }
    }

    func stopStreaming() {
        let (session, stream) = stateQueue.sync { () -> (Int, AudioStreamTranscriber?) in
            sessionID += 1 // invalidates any start still in flight
            return (sessionID, streamer)
        }
        let onFinal = onFinalHandler

        Task {
            await stream?.stopStreamTranscription()
            let text = stateQueue.sync { latestText }
            Self.logger.debug("Whisper final: \(text, privacy: .public)")
            onFinal?(text)
        }
    }

    /// Memoized so concurrent callers (preload + streaming itself) share one
    /// in-flight download/load instead of racing separate WhisperKit() calls.
    private func loadedWhisperKit() -> Task<WhisperKit, Error> {
        if let loadTask {
            return loadTask
        }
        let task = Task<WhisperKit, Error> {
            // load: true is required here — unlike the old batch transcribe() call, which
            // lazily loaded models itself, AudioStreamTranscriber reads kit.tokenizer etc.
            // directly and needs them already populated.
            let kit = try await WhisperKit(model: modelName, load: true)
            Self.logger.debug("WhisperKit model loaded: \(self.modelName, privacy: .public)")
            return kit
        }
        loadTask = task
        return task
    }
}
