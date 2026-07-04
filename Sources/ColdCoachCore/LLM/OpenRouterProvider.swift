import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenRouter client (raw HTTP). OpenRouter is byte-for-byte OpenAI-compatible on
/// both the request and response, so encoding and parsing are reused verbatim from
/// `OpenAIProvider`; only the endpoint and two attribution headers differ.
///
///   POST https://openrouter.ai/api/v1/chat/completions
///   headers: Authorization: Bearer <key>, content-type: application/json,
///            HTTP-Referer + X-Title (OpenRouter app attribution — recommended)
///   model IDs are namespaced, e.g. "openai/gpt-4o-mini", "anthropic/claude-...".
///
/// One key fronts many providers; the user brings a single OpenRouter key.
public struct OpenRouterProvider: LLMProvider {
    public static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    public static let referer = "https://github.com/tiXor-code/coldcoach"
    public static let title = "ColdCoach"

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Pure helpers (reuse OpenAI's wire format, so there is one source of truth)

    public static func encodeBody(_ request: LLMRequest) throws -> Data {
        try OpenAIProvider.encodeBody(request)
    }

    public static func parseText(status: Int, data: Data) throws -> String {
        try OpenAIProvider.parseText(status: status, data: data)
    }

    public func buildURLRequest(_ request: LLMRequest) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(Self.referer, forHTTPHeaderField: "HTTP-Referer")
        req.setValue(Self.title, forHTTPHeaderField: "X-Title")
        req.httpBody = try Self.encodeBody(request)
        return req
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
