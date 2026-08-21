import Foundation

/// Where WhisperKit stores downloaded models on disk, so Settings can show/delete them.
enum WhisperModelStorage {
    private static let modelsDirectory: URL? = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true)
    }()

    static func localURL(for modelID: String) -> URL? {
        modelsDirectory?.appendingPathComponent(modelID, isDirectory: true)
    }

    static func isDownloaded(_ modelID: String) -> Bool {
        guard let url = localURL(for: modelID) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func delete(_ modelID: String) {
        guard let url = localURL(for: modelID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
