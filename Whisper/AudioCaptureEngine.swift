import AVFoundation
import os

final class AudioCaptureEngine {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Whisper", category: "AudioCaptureEngine")

    private let engine = AVAudioEngine()

    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onLevel: ((Float) -> Void)?

    private(set) var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        Self.logger.debug("input format: \(String(describing: inputFormat), privacy: .public)")

        // SFSpeechAudioBufferRecognitionRequest expects the mic's native format
        // and resamples internally — don't pre-convert here.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
            self?.onLevel?(Self.rms(of: buffer))
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<frameLength {
            sum += samples[index] * samples[index]
        }
        return (sum / Float(frameLength)).squareRoot()
    }
}
