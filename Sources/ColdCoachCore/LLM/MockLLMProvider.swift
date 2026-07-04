import Foundation

/// Deterministic in-memory provider for tests and offline development.
///
/// Feed it scripted responses (consumed in order; the last one repeats once exhausted)
/// and inspect the requests it received.
public final class MockLLMProvider: LLMProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String]
    private var cursor = 0
    private var _received: [LLMRequest] = []
    /// When set, `complete` throws this instead of returning text.
    public var errorToThrow: LLMError?

    public init(responses: [String] = []) {
        self.responses = responses
    }

    public convenience init(response: String) {
        self.init(responses: [response])
    }

    public var receivedRequests: [LLMRequest] {
        lock.lock(); defer { lock.unlock() }
        return _received
    }

    public func complete(_ request: LLMRequest) async throws -> String {
        lock.lock()
        _received.append(request)
        let err = errorToThrow
        let response: String
        if responses.isEmpty {
            response = ""
        } else if cursor < responses.count {
            response = responses[cursor]
            cursor += 1
        } else {
            response = responses[responses.count - 1]
        }
        lock.unlock()

        if let err { throw err }
        if response.isEmpty { throw LLMError.emptyResponse("mock had no scripted response") }
        return response
    }
}
