import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI Chat Completions client (raw HTTP).
///
///   POST https://api.openai.com/v1/chat/completions
///   headers: Authorization: Bearer <key>, content-type: application/json
///   body:    { model, max_tokens, messages: [{role, content}] }  (system is a message)
///   reply:   { choices: [{ message: { content } }] }
public struct OpenAIProvider: LLMProvider {
    public static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    struct WireRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let max_tokens: Int
        let messages: [Message]
    }

    public static func encodeBody(_ request: LLMRequest) throws -> Data {
        var messages: [WireRequest.Message] = []
        if let s = request.system, !s.isEmpty {
            messages.append(.init(role: "system", content: s))
        }
        for m in request.messages {
            messages.append(.init(role: m.role.rawValue, content: m.content))
        }
        let wire = WireRequest(model: request.model, max_tokens: request.maxTokens, messages: messages)
        return try JSONEncoder().encode(wire)
    }

    public func buildURLRequest(_ request: LLMRequest) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try Self.encodeBody(request)
        return req
    }

    struct WireResponse: Decodable {
        struct Choice: Decodable { struct Message: Decodable { let content: String? }; let message: Message }
        let choices: [Choice]?
    }

    struct WireError: Decodable {
        struct Inner: Decodable { let message: String? }
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
        let text = decoded.choices?.first?.message.content ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.emptyResponse("no choices")
        }
        return text
    }

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
