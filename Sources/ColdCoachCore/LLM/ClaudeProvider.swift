import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Anthropic Messages API client (raw HTTP — there is no official Swift SDK).
///
/// Wire contract (verified against the Claude API reference):
///   POST https://api.anthropic.com/v1/messages
///   headers: x-api-key, anthropic-version: 2023-06-01, content-type: application/json
///   body:    { model, max_tokens, system?, messages: [{role, content}] }
///   reply:   { content: [{type:"text", text:"..."}], stop_reason, ... }
///
/// Request building and response parsing are exposed as pure functions so tests can
/// exercise them without hitting the network.
public struct ClaudeProvider: LLMProvider {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersion = "2023-06-01"

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Pure helpers (unit-tested)

    struct WireRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [Message]
    }

    public static func encodeBody(_ request: LLMRequest) throws -> Data {
        // Anthropic requires user/assistant only in messages; system is top-level.
        // Fold any stray system messages into the top-level system field.
        var systemParts: [String] = []
        if let s = request.system, !s.isEmpty { systemParts.append(s) }
        var wireMessages: [WireRequest.Message] = []
        for m in request.messages {
            switch m.role {
            case .system: systemParts.append(m.content)
            case .user: wireMessages.append(.init(role: "user", content: m.content))
            case .assistant: wireMessages.append(.init(role: "assistant", content: m.content))
            }
        }
        if wireMessages.isEmpty {
            wireMessages.append(.init(role: "user", content: " "))
        }
        let wire = WireRequest(
            model: request.model,
            max_tokens: request.maxTokens,
            system: systemParts.isEmpty ? nil : systemParts.joined(separator: "\n\n"),
            messages: wireMessages
        )
        return try JSONEncoder().encode(wire)
    }

    public func buildURLRequest(_ request: LLMRequest) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try Self.encodeBody(request)
        return req
    }

    struct WireResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]?
        let stop_reason: String?
    }

    struct WireError: Decodable {
        struct Inner: Decodable { let type: String?; let message: String? }
        let error: Inner?
    }

    public static func parseText(status: Int, data: Data) throws -> String {
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(WireError.self, from: data))?.error?.message
                ?? String(data: data, encoding: .utf8)
                ?? "unknown error"
            throw LLMError.http(status, message)
        }
        let decoded: WireResponse
        do {
            decoded = try JSONDecoder().decode(WireResponse.self, from: data)
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }
        if decoded.stop_reason == "refusal" {
            throw LLMError.emptyResponse("refusal")
        }
        let text = (decoded.content ?? [])
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.emptyResponse("no text blocks")
        }
        return text
    }

    // MARK: - LLMProvider

    public func complete(_ request: LLMRequest) async throws -> String {
        let urlRequest = try buildURLRequest(request)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw LLMError.transport(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.parseText(status: status, data: data)
    }
}
