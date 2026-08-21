import AVFoundation
import WhisperKit
import os

final class WhisperKitEngine: TranscriptionEngine {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "WhisperKitEngine")
    private static let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private static let modelName = "openai_whisper-base"

    private var loadTask: Task<WhisperKit, Error>?
    private var converter: AVAudioConverter?
    private var samples: [Float] = []

    private var onFinalHandler: ((String) -> Void)?
    private var onErrorHandler: ((Error) -> Void)?

    /// Kicks off (or reuses) the model load without blocking the caller — call as soon as
    /// this engine is selected so the model is likely ready by the time recording starts.
    func preload() {
        _ = loadedWhisperKit()
    }

    func startStreaming(onPartial: @escaping (String) -> Void,
                         onFinal: @escaping (String) -> Void,
                         onError: @escaping (Error) -> Void) throws {
        samples = []
        converter = nil
        onFinalHandler = onFinal
        onErrorHandler = onError
        preload()
    }

    func appendAudio(_ buffer: AVAudioPCMBuffer) {
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: Self.targetFormat)
        }
        guard let converter else { return }

        let ratio = Self.targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            guard !consumed else {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard conversionError == nil, let channelData = outputBuffer.floatChannelData else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength)))
    }

    func stopStreaming() {
        let capturedSamples = samples
        let onFinal = onFinalHandler
        let onError = onErrorHandler
        samples = []

        guard !capturedSamples.isEmpty else {
            onFinal?("")
            return
        }

        Task {
            do {
                let kit = try await loadedWhisperKit().value
                let results = try await kit.transcribe(audioArray: capturedSamples)
                let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                Self.logger.debug("Whisper final: \(text, privacy: .public)")
                onFinal?(text)
            } catch {
                Self.logger.error("Whisper transcription failed: \(String(describing: error), privacy: .public)")
                onError?(error)
            }
        }
    }

    /// Memoized so concurrent callers (preload + the transcription itself) share one
    /// in-flight download/load instead of racing separate WhisperKit() calls.
    private func loadedWhisperKit() -> Task<WhisperKit, Error> {
        if let loadTask {
            return loadTask
        }
        let task = Task<WhisperKit, Error> {
            let kit = try await WhisperKit(model: Self.modelName)
            Self.logger.debug("WhisperKit model loaded")
            return kit
        }
        loadTask = task
        return task
    }
}
