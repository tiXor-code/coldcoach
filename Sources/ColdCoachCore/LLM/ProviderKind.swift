import Foundation

/// Which reasoning backend the user has configured (BYO key).
public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case anthropic
    case openai

    public var displayName: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        }
    }

    /// Fast model for the latency-critical live coaching cards.
    /// (The approved plan chose Haiku / gpt-4o-mini for sub-2s cards.)
    public var defaultCoachingModel: String {
        switch self {
        case .anthropic: return "claude-haiku-4-5"
        case .openai: return "gpt-4o-mini"
        }
    }

    /// Higher-quality model for one-off playbook generation (not latency-critical).
    public var defaultPlaybookModel: String {
        switch self {
        case .anthropic: return "claude-opus-4-8"
        case .openai: return "gpt-4o"
        }
    }

    /// Where the user gets a key, shown in onboarding.
    public var keyURL: String {
        switch self {
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .openai: return "https://platform.openai.com/api-keys"
        }
    }
}
