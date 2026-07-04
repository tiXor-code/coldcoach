import Foundation

/// User-configurable settings, persisted as JSON. The API key is NOT stored here —
/// it lives in the macOS Keychain (see the app layer).
public struct AppSettings: Codable, Sendable, Equatable {
    public var provider: ProviderKind
    /// Model for live coaching cards (latency-critical).
    public var coachingModel: String
    /// Model for one-off playbook generation (quality over latency).
    public var playbookModel: String
    public var defaultAudioMode: AudioMode
    /// Run SpeakerKit diarization in Mode A. When false, roles are inferred by the LLM.
    public var diarizationEnabled: Bool
    /// WhisperKit model name (downloaded on first run). "base" is a fast, safe default.
    public var whisperModel: String
    public var overlayOpacity: Double
    /// Check GitHub Releases for a newer version on launch (and via the menu).
    public var autoUpdateEnabled: Bool
    /// When the last update check ran; used to throttle to ~once/day.
    public var lastUpdateCheck: Date?

    public init(
        provider: ProviderKind = .anthropic,
        coachingModel: String? = nil,
        playbookModel: String? = nil,
        defaultAudioMode: AudioMode = .speakerphoneMic,
        diarizationEnabled: Bool = true,
        whisperModel: String = "base",
        overlayOpacity: Double = 0.95,
        autoUpdateEnabled: Bool = true,
        lastUpdateCheck: Date? = nil
    ) {
        self.provider = provider
        self.coachingModel = coachingModel ?? provider.defaultCoachingModel
        self.playbookModel = playbookModel ?? provider.defaultPlaybookModel
        self.defaultAudioMode = defaultAudioMode
        self.diarizationEnabled = diarizationEnabled
        self.whisperModel = whisperModel
        self.overlayOpacity = overlayOpacity
        self.autoUpdateEnabled = autoUpdateEnabled
        self.lastUpdateCheck = lastUpdateCheck
    }

    public static let `default` = AppSettings()

    /// Reset the model names to the provider's defaults (used when switching provider in the UI).
    public mutating func resetModelsForProvider() {
        coachingModel = provider.defaultCoachingModel
        playbookModel = provider.defaultPlaybookModel
    }
}
