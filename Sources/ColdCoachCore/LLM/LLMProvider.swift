import Foundation

public enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct LLMMessage: Sendable, Equatable {
    public var role: LLMRole
    public var content: String

    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// A provider-agnostic completion request. `system` is carried separately so each
/// provider can place it correctly (Anthropic: top-level `system`; OpenAI: a system message).
public struct LLMRequest: Sendable, Equatable {
    public var model: String
    public var system: String?
    public var messages: [LLMMessage]
    public var maxTokens: Int

    public init(model: String, system: String? = nil, messages: [LLMMessage], maxTokens: Int) {
        self.model = model
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
    }

    /// Convenience for the common single-user-turn request.
    public static func single(model: String, system: String?, user: String, maxTokens: Int) -> LLMRequest {
        LLMRequest(model: model, system: system, messages: [LLMMessage(role: .user, content: user)], maxTokens: maxTokens)
    }
}

public enum LLMError: Error, Equatable {
    case missingKey
    case http(Int, String)
    case decoding(String)
    case emptyResponse(String)
    case transport(String)
}

extension LLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingKey: return "No API key configured. Add your provider key in Settings."
        case let .http(code, message): return "Provider returned HTTP \(code): \(message)"
        case let .decoding(message): return "Could not read the provider response: \(message)"
        case let .emptyResponse(reason): return "The provider returned no usable text (\(reason))."
        case let .transport(message): return "Network error talking to the provider: \(message)"
        }
    }
}

/// Everything the app needs from an LLM backend. Implemented by ClaudeProvider,
/// OpenAIProvider, and MockLLMProvider (and, later, an Ollama provider).
public protocol LLMProvider: Sendable {
    func complete(_ request: LLMRequest) async throws -> String
}
