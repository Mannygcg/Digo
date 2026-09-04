import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var dictationController: DictationController
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    @State private var storageRefreshID = UUID()

    private var availableModels: [WhisperModelOption] {
        WhisperModelCatalog.all.filter { !dictationController.enabledModelIDs.contains($0.id) }
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        LaunchAtLoginManager.setEnabled(newValue)
                    }
            }

            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Toggle Dictation:", name: .toggleDictation)
            }

            Section("Voice Commands") {
                voiceCommandRow(phrase: "\u{201c}open quote\u{201d} / \u{201c}close quote\u{201d}", effect: "Types a literal \" character.")
                voiceCommandRow(phrase: "\u{201c}open parenthesis\u{201d} / \u{201c}close parenthesis\u{201d}", effect: "Types ( or ).")
                voiceCommandRow(phrase: "\u{201c}comma\u{201d}, \u{201c}period\u{201d}, \u{201c}question mark\u{201d}, \u{201c}exclamation point\u{201d}", effect: "Types the matching punctuation.")
                voiceCommandRow(phrase: "\u{201c}new paragraph\u{201d}", effect: "Starts a new paragraph.")
                voiceCommandRow(phrase: "\u{201c}scratch that\u{201d}", effect: "Deletes the last sentence you dictated.")
                voiceCommandRow(phrase: "\u{201c}scratch last one\u{201d} / \u{201c}scratch last three\u{201d}", effect: "Deletes the last word, or the last N words.")

                Stepper(value: $dictationController.scratchThatWordLimit, in: 1...30) {
                    Text("\u{201c}Scratch that\u{201d} deletes at most \(dictationController.scratchThatWordLimit) words")
                }
                Text("If the last sentence is longer than that, only the last \(dictationController.scratchThatWordLimit) words are removed instead of the whole sentence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Engines") {
                ForEach(dictationController.enabledModelIDs, id: \.self) { modelID in
                    engineRow(modelID: modelID)
                }
            }
            .id(storageRefreshID)

            if !availableModels.isEmpty {
                Section("Add Engine") {
                    ForEach(availableModels, id: \.id) { option in
                        addEngineRow(option)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 700)
    }

    @ViewBuilder
    private func voiceCommandRow(phrase: String, effect: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phrase)
            Text(effect)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func engineRow(modelID: String) -> some View {
        let option = WhisperModelCatalog.option(for: modelID)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option?.displayName ?? modelID)
                if let note = option?.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if modelID == dictationController.selectedModelID {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            } else {
                Button("Use") {
                    dictationController.selectedModelID = modelID
                }
            }
            if WhisperModelStorage.isDownloaded(modelID) {
                Button {
                    WhisperModelStorage.delete(modelID)
                    storageRefreshID = UUID()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete the downloaded model to free up disk space")
            }
        }
    }

    @ViewBuilder
    private func addEngineRow(_ option: WhisperModelOption) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                if let note = option.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Add") {
                dictationController.addEnabledModel(option.id)
            }
        }
    }
}
