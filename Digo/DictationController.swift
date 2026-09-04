import Foundation
import os

enum DictationState {
    case idle
    case listening
    case transcribing
}

final class DictationController: ObservableObject {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "DictationController")
    private static let selectedModelDefaultsKey = "selectedWhisperModel"
    private static let enabledModelsDefaultsKey = "enabledWhisperModels"
    private static let scratchThatWordLimitDefaultsKey = "scratchThatWordLimit"
    private static let defaultScratchThatWordLimit = 7

    private var engines: [String: WhisperKitEngine] = [:]

    private func engine(for modelID: String) -> WhisperKitEngine {
        if let existing = engines[modelID] {
            return existing
        }
        let engine = WhisperKitEngine(modelName: modelID)
        engines[modelID] = engine
        return engine
    }

    private var activeEngine: WhisperKitEngine { engine(for: selectedModelID) }

    /// Models available in the Engine menu. Adding one here doesn't download it —
    /// that only happens the first time it's actually selected.
    @Published var enabledModelIDs: [String] {
        didSet { UserDefaults.standard.set(enabledModelIDs, forKey: Self.enabledModelsDefaultsKey) }
    }

    func addEnabledModel(_ modelID: String) {
        guard !enabledModelIDs.contains(modelID) else { return }
        enabledModelIDs.append(modelID)
    }

    @Published var selectedModelID: String {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelDefaultsKey)
            engine(for: selectedModelID).preload()
        }
    }

    /// How many words "scratch that" removes when the last sentence is longer than this.
    @Published var scratchThatWordLimit: Int {
        didSet { UserDefaults.standard.set(scratchThatWordLimit, forKey: Self.scratchThatWordLimitDefaultsKey) }
    }

    private(set) var state: DictationState = .idle {
        didSet { onStateChange?(state) }
    }

    private static let recentTranscriptsLimit = 3
    @Published private(set) var recentTranscripts: [String] = []

    private func recordTranscript(_ text: String) {
        guard !text.isEmpty else { return }
        recentTranscripts.insert(text, at: 0)
        if recentTranscripts.count > Self.recentTranscriptsLimit {
            recentTranscripts.removeLast(recentTranscripts.count - Self.recentTranscriptsLimit)
        }
    }

    var onStateChange: ((DictationState) -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onEngineError: ((Error) -> Void)?

    init() {
        enabledModelIDs = UserDefaults.standard.stringArray(forKey: Self.enabledModelsDefaultsKey)
            ?? WhisperModelCatalog.all.filter(\.isDefault).map(\.id)
        selectedModelID = UserDefaults.standard.string(forKey: Self.selectedModelDefaultsKey)
            ?? WhisperModelCatalog.defaultSelection
        let storedLimit = UserDefaults.standard.object(forKey: Self.scratchThatWordLimitDefaultsKey) as? Int
        scratchThatWordLimit = storedLimit ?? Self.defaultScratchThatWordLimit
        engine(for: selectedModelID).preload()
    }

    func toggle() {
        switch state {
        case .idle:
            start()
        case .listening:
            stop()
        case .transcribing:
            break
        }
    }

    private func start() {
        Self.logger.debug("start() called, engine=\(self.selectedModelID, privacy: .public)")
        do {
            let scratchThatWordLimit = scratchThatWordLimit
            try activeEngine.startStreaming(
                onPartial: { [weak self] rawText in
                    let text = VoiceCommandFormatter.apply(to: rawText, scratchThatWordLimit: scratchThatWordLimit)
                    Self.logger.debug("partial: \(text, privacy: .public)")
                    DispatchQueue.main.async { self?.onPartialTranscript?(text) }
                },
                onFinal: { [weak self] rawText in
                    let text = VoiceCommandFormatter.apply(to: rawText, scratchThatWordLimit: scratchThatWordLimit)
                    Self.logger.debug("final: \(text, privacy: .public)")
                    DispatchQueue.main.async {
                        self?.recordTranscript(text)
                        self?.onFinalTranscript?(text)
                        self?.state = .idle
                    }
                },
                onError: { [weak self] error in
                    Self.logger.error("Transcription error: \(String(describing: error), privacy: .public)")
                    DispatchQueue.main.async {
                        self?.onEngineError?(error)
                        self?.state = .idle
                    }
                }
            )
            state = .listening
            Self.logger.debug("state -> listening")
        } catch {
            Self.logger.error("Failed to start dictation: \(String(describing: error), privacy: .public)")
        }
    }

    private func stop() {
        Self.logger.debug("stop() called")
        activeEngine.stopStreaming()
        state = .transcribing
    }
}
