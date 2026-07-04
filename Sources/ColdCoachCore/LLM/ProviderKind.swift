import Foundation

/// Which reasoning backend the user has configured (BYO key).
public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case anthropic
    case openai
    case openrouter

    public var displayName: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        }
    }

    /// Fast model for the latency-critical live coaching cards.
    /// (The approved plan chose Haiku / gpt-4o-mini for sub-2s cards.)
    /// OpenRouter model IDs are namespaced; these are safe, universally-available
    /// defaults and are editable in Settings (see https://openrouter.ai/models).
    public var defaultCoachingModel: String {
        switch self {
        case .anthropic: return "claude-haiku-4-5"
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        }
    }

    /// Higher-quality model for one-off playbook generation (not latency-critical).
    public var defaultPlaybookModel: String {
        switch self {
        case .anthropic: return "claude-opus-4-8"
        case .openai: return "gpt-4o"
        case .openrouter: return "openai/gpt-4o"
        }
    }

    /// Where the user gets a key, shown in onboarding.
    public var keyURL: String {
        switch self {
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .openai: return "https://platform.openai.com/api-keys"
        case .openrouter: return "https://openrouter.ai/keys"
        }
    }
}
