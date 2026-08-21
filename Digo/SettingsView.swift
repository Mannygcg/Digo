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
        .frame(width: 440, height: 480)
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
