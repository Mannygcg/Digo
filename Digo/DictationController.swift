import Foundation
import Speech
import os

enum DictationState {
    case idle
    case listening
}

final class DictationController {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "DictationController")
    private static let selectedEngineDefaultsKey = "selectedEngine"

    private let audioCaptureEngine = AudioCaptureEngine()
    private let appleSpeechEngine = AppleSpeechEngine()
    private let whisperKitEngine = WhisperKitEngine()

    private var activeEngine: TranscriptionEngine {
        switch selectedEngineKind {
        case .appleSpeech: return appleSpeechEngine
        case .whisperKit: return whisperKitEngine
        }
    }

    var selectedEngineKind: TranscriptionEngineKind {
        get {
            TranscriptionEngineKind(rawValue: UserDefaults.standard.string(forKey: Self.selectedEngineDefaultsKey) ?? "") ?? .appleSpeech
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.selectedEngineDefaultsKey)
            if newValue == .whisperKit {
                whisperKitEngine.preload()
            }
        }
    }

    private(set) var state: DictationState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((DictationState) -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onEngineError: ((Error) -> Void)?

    init() {
        if selectedEngineKind == .whisperKit {
            whisperKitEngine.preload()
        }
        audioCaptureEngine.onBuffer = { [weak self] buffer in
            self?.activeEngine.appendAudio(buffer)
        }
        var levelLogCount = 0
        audioCaptureEngine.onLevel = { level in
            levelLogCount += 1
            if levelLogCount % 5 == 0 {
                Self.logger.debug("level: \(level, privacy: .public)")
            }
        }
    }

    func toggle() {
        switch state {
        case .idle:
            if selectedEngineKind == .appleSpeech {
                requestAuthorizationIfNeeded { [weak self] authorized in
                    guard authorized else {
                        Self.logger.error("Speech recognition not authorized")
                        return
                    }
                    self?.start()
                }
            } else {
                start()
            }
        case .listening:
            stop()
        }
    }

    private func requestAuthorizationIfNeeded(_ completion: @escaping (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { completion(status == .authorized) }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func start() {
        Self.logger.debug("start() called, engine=\(self.selectedEngineKind.rawValue, privacy: .public)")
        do {
            try activeEngine.startStreaming(
                onPartial: { [weak self] text in
                    Self.logger.debug("partial: \(text, privacy: .public)")
                    DispatchQueue.main.async { self?.onPartialTranscript?(text) }
                },
                onFinal: { [weak self] text in
                    Self.logger.debug("final: \(text, privacy: .public)")
                    DispatchQueue.main.async { self?.onFinalTranscript?(text) }
                },
                onError: { [weak self] error in
                    Self.logger.error("Transcription error: \(String(describing: error), privacy: .public)")
                    DispatchQueue.main.async { self?.onEngineError?(error) }
                }
            )
            try audioCaptureEngine.start()
            state = .listening
            Self.logger.debug("state -> listening")
        } catch {
            Self.logger.error("Failed to start dictation: \(String(describing: error), privacy: .public)")
        }
    }

    private func stop() {
        Self.logger.debug("stop() called")
        audioCaptureEngine.stop()
        activeEngine.stopStreaming()
        state = .idle
    }
}
