import AVFoundation

protocol TranscriptionEngine: AnyObject {
    func startStreaming(onPartial: @escaping (String) -> Void,
                         onFinal: @escaping (String) -> Void,
                         onError: @escaping (Error) -> Void) throws
    func appendAudio(_ buffer: AVAudioPCMBuffer)
    func stopStreaming()
}

enum TranscriptionEngineError: Error {
    case recognizerUnavailable
}
