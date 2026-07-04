import Foundation
import SwiftUI
import ColdCoachCore

/// App-wide state: settings, playbooks, call history, and the current API-key status.
/// Owns the persistence Store and builds LLM providers from the configured key.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published private(set) var playbooks: [Playbook] = []
    @Published private(set) var calls: [CallRecord] = []
    @Published private(set) var hasAPIKey: Bool = false

    let store: Store

    init(store: Store) {
        self.store = store
        self.settings = (try? store.loadSettings()) ?? .default
        reloadPlaybooks()
        reloadCalls()
        refreshKeyState()
    }

    static func live() -> AppModel {
        let store: Store
        if let appSupport = try? JSONFileStore.applicationSupport() {
            store = appSupport
        } else {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("ColdCoach", isDirectory: true)
            store = (try? JSONFileStore(baseDirectory: fallback)) ?? (try! JSONFileStore(baseDirectory: FileManager.default.temporaryDirectory))
        }
        return AppModel(store: store)
    }

    var needsOnboarding: Bool { !hasAPIKey }

    // MARK: - API key / providers

    func refreshKeyState() { hasAPIKey = KeychainStore.read(for: settings.provider) != nil }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed, for: settings.provider)
        refreshKeyState()
    }

    func clearAPIKey() {
        KeychainStore.delete(for: settings.provider)
        refreshKeyState()
    }

    func makeProvider() -> LLMProvider? {
        guard let key = KeychainStore.read(for: settings.provider) else { return nil }
        switch settings.provider {
        case .anthropic: return ClaudeProvider(apiKey: key)
        case .openai: return OpenAIProvider(apiKey: key)
        }
    }

    // MARK: - Settings

    func saveSettings() {
        try? store.saveSettings(settings)
        refreshKeyState()
    }

    // MARK: - Playbooks

    func reloadPlaybooks() { playbooks = (try? store.loadPlaybooks()) ?? [] }
    func upsertPlaybook(_ playbook: Playbook) { try? store.savePlaybook(playbook); reloadPlaybooks() }
    func deletePlaybook(_ id: UUID) { try? store.deletePlaybook(id: id); reloadPlaybooks() }

    // MARK: - Calls

    func reloadCalls() { calls = ((try? store.loadCalls()) ?? []).sorted { $0.startedAt > $1.startedAt } }
    func saveCall(_ call: CallRecord) { try? store.saveCall(call); reloadCalls() }
    func deleteCall(_ id: UUID) { try? store.deleteCall(id: id); reloadCalls() }
}
