import SwiftUI
import ColdCoachCore

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: PermissionsManager
    @State private var apiKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to ColdCoach")
                        .font(.largeTitle.bold())
                    Text("Local, open-source live coaching for cold calls. Call better, not more.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("1. Connect your AI") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Provider", selection: providerBinding) {
                            ForEach(ProviderKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        SecureField("Paste your \(model.settings.provider.displayName) API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Save key") { model.saveAPIKey(apiKey); apiKey = "" }
                                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                            Link("Get a key ↗", destination: URL(string: model.settings.provider.keyURL)!)
                                .font(.callout)
                            Spacer()
                            if model.hasAPIKey {
                                Label("Key saved", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                            }
                        }
                        Text("Your key is stored in the macOS Keychain and used only to call your provider directly. Transcription runs on-device.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("2. Grant permissions") {
                    VStack(alignment: .leading, spacing: 12) {
                        permissionRow(
                            title: "Microphone",
                            subtitle: "Required for both call modes.",
                            granted: permissions.micGranted,
                            grant: { Task { _ = await permissions.requestMicrophone() } },
                            open: { permissions.openMicrophoneSettings() }
                        )
                        permissionRow(
                            title: "Screen Recording",
                            subtitle: "Only needed for System-audio mode (softphone / Zoom).",
                            granted: permissions.screenGranted,
                            grant: { _ = permissions.requestScreenRecording() },
                            open: { permissions.openScreenRecordingSettings() }
                        )
                    }
                    .padding(6)
                }

                Text("Next: open the Playbooks tab to create your first playbook from a one-sentence offer.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(maxWidth: 640)
        }
        .onAppear { permissions.refresh() }
    }

    private var providerBinding: Binding<ProviderKind> {
        Binding(
            get: { model.settings.provider },
            set: { newValue in
                model.settings.provider = newValue
                model.settings.resetModelsForProvider()
                model.saveSettings()
            }
        )
    }

    @ViewBuilder
    private func permissionRow(title: String, subtitle: String, granted: Bool, grant: @escaping () -> Void, open: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted").font(.caption).foregroundStyle(.green)
            } else {
                Button("Grant", action: grant)
                Button("Settings", action: open).buttonStyle(.link)
            }
        }
    }
}
