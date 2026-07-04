import SwiftUI
import ColdCoachCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: PermissionsManager
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section("AI provider") {
                Picker("Provider", selection: providerBinding) {
                    ForEach(ProviderKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("Coaching model (fast)", text: $model.settings.coachingModel)
                TextField("Playbook model (quality)", text: $model.settings.playbookModel)

                HStack {
                    SecureField("API key", text: $apiKey)
                    Button("Save") { model.saveAPIKey(apiKey); apiKey = "" }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                HStack {
                    if model.hasAPIKey {
                        Label("Key saved in Keychain", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.caption)
                        Spacer()
                        Button("Remove key", role: .destructive) { model.clearAPIKey() }.font(.caption)
                    } else {
                        Label("No key saved", systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.caption)
                        Spacer()
                        Link("Get a key ↗", destination: URL(string: model.settings.provider.keyURL)!).font(.caption)
                    }
                }
            }

            Section("Call") {
                Picker("Default mode", selection: $model.settings.defaultAudioMode) {
                    ForEach(AudioMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("WhisperKit model", text: $model.settings.whisperModel)
                    .help("On-device speech model, downloaded on first use (e.g. base, small, distil-large-v3).")
                VStack(alignment: .leading) {
                    Text("Overlay opacity: \(Int(model.settings.overlayOpacity * 100))%").font(.caption)
                    Slider(value: $model.settings.overlayOpacity, in: 0.5...1.0)
                }
            }

            Section("Permissions") {
                LabeledContent("Microphone") {
                    permissionStatus(granted: permissions.micGranted, grant: { Task { _ = await permissions.requestMicrophone() } }, open: permissions.openMicrophoneSettings)
                }
                LabeledContent("Screen Recording") {
                    permissionStatus(granted: permissions.screenGranted, grant: { _ = permissions.requestScreenRecording() }, open: permissions.openScreenRecordingSettings)
                }
            }

            Section("About") {
                LabeledContent("ColdCoach", value: "v0.1 · MIT · local-first")
                Link("Source & docs ↗", destination: URL(string: "https://github.com/tiXor-code/coldcoach")!)
                Text("Transcription runs on-device (WhisperKit). Only your provider sees text you send it. Nothing is uploaded anywhere else.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: model.settings) { _, _ in model.saveSettings() }
        .onAppear { permissions.refresh() }
    }

    private var providerBinding: Binding<ProviderKind> {
        Binding(
            get: { model.settings.provider },
            set: { newValue in
                model.settings.provider = newValue
                model.settings.resetModelsForProvider()
                model.refreshKeyState()
            }
        )
    }

    @ViewBuilder
    private func permissionStatus(granted: Bool, grant: @escaping () -> Void, open: @escaping () -> Void) -> some View {
        if granted {
            Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            HStack {
                Button("Grant", action: grant)
                Button("Settings", action: open).buttonStyle(.link)
            }
        }
    }
}
