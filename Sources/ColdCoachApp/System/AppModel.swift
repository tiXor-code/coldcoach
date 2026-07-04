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
    /// Set when a newer release is available; drives the Settings row and the update banner.
    @Published var availableUpdate: UpdateInfo?

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
        case .openrouter: return OpenRouterProvider(apiKey: key)
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

    // MARK: - Software update (check + assisted; never self-replaces the binary)

    /// This build's version, read from the bundle (the single runtime source of truth).
    var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    var currentVersion: SemVer { SemVer(currentVersionString) ?? SemVer(major: 0, minor: 0, patch: 0) }

    /// Check GitHub Releases for a newer version. Respects the auto-update toggle and
    /// throttles to ~once/day unless `force` (the menu / "Check now" button).
    func checkForUpdates(force: Bool = false) async {
        guard force || settings.autoUpdateEnabled else { return }
        if !force, let last = settings.lastUpdateCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
        let release = await GitHubReleaseClient().fetchLatest()
        settings.lastUpdateCheck = Date()
        saveSettings()
        guard let release else { availableUpdate = nil; return }
        switch ReleaseCheck.updateDecision(current: currentVersion, release: release) {
        case .upToDate:
            availableUpdate = nil
        case let .available(version, releaseURL, dmgURL):
            availableUpdate = UpdateInfo(version: version, releaseURL: releaseURL, dmgURL: dmgURL, channel: InstallChannelDetector.detect())
        }
    }
}

/// A pending update plus how to install it (depends on how this copy was installed).
struct UpdateInfo: Equatable {
    let version: SemVer
    let releaseURL: String
    let dmgURL: String?
    let channel: InstallChannel

    /// The Homebrew upgrade command (used when installed via cask).
    static let brewCommand = "brew upgrade --cask coldcoach"

    var explanation: String {
        switch channel {
        case .brew: return "Installed via Homebrew. Run \(Self.brewCommand)."
        case .dmg: return "Download the new .dmg from the release page."
        case .source: return "Built from source. See the release notes."
        }
    }
}
