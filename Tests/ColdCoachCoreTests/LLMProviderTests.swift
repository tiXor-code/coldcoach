import XCTest
@testable import ColdCoachCore

final class LLMProviderTests: XCTestCase {
    // MARK: - Claude

    func testClaudeEncodeLiftsSystemAndKeepsUserAssistantOnly() throws {
        let req = LLMRequest(
            model: "claude-haiku-4-5",
            system: "S1",
            messages: [LLMMessage(role: .system, content: "S2"), LLMMessage(role: .user, content: "hi")],
            maxTokens: 100
        )
        let data = try ClaudeProvider.encodeBody(req)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["model"] as? String, "claude-haiku-4-5")
        XCTAssertEqual(obj["max_tokens"] as? Int, 100)
        let system = try XCTUnwrap(obj["system"] as? String)
        XCTAssertTrue(system.contains("S1"))
        XCTAssertTrue(system.contains("S2"))
        let messages = try XCTUnwrap(obj["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "hi")
    }

    func testClaudeParseJoinsTextBlocksAndIgnoresThinking() throws {
        let json = #"{"content":[{"type":"text","text":"Hello "},{"type":"thinking"},{"type":"text","text":"world"}],"stop_reason":"end_turn"}"#
        let text = try ClaudeProvider.parseText(status: 200, data: Data(json.utf8))
        XCTAssertEqual(text, "Hello world")
    }

    func testClaudeParseRefusalThrows() {
        let json = #"{"content":[],"stop_reason":"refusal"}"#
        XCTAssertThrowsError(try ClaudeProvider.parseText(status: 200, data: Data(json.utf8))) { error in
            guard case LLMError.emptyResponse = error else { return XCTFail("expected emptyResponse, got \(error)") }
        }
    }

    func testClaudeParseHTTPErrorSurfacesMessage() {
        let json = #"{"type":"error","error":{"type":"invalid_request_error","message":"bad model"}}"#
        XCTAssertThrowsError(try ClaudeProvider.parseText(status: 400, data: Data(json.utf8))) { error in
            guard case let LLMError.http(code, message) = error else { return XCTFail("expected http error, got \(error)") }
            XCTAssertEqual(code, 400)
            XCTAssertEqual(message, "bad model")
        }
    }

    func testClaudeBuildURLRequestMissingKeyThrows() {
        let provider = ClaudeProvider(apiKey: "")
        XCTAssertThrowsError(try provider.buildURLRequest(.single(model: "m", system: nil, user: "hi", maxTokens: 1))) { error in
            guard case LLMError.missingKey = error else { return XCTFail("expected missingKey") }
        }
    }

    // MARK: - OpenAI

    func testOpenAIEncodePutsSystemFirst() throws {
        let req = LLMRequest(model: "gpt-4o-mini", system: "S", messages: [LLMMessage(role: .user, content: "hi")], maxTokens: 50)
        let data = try OpenAIProvider.encodeBody(req)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(obj["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "S")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
    }

    func testOpenAIParseSuccess() throws {
        let json = #"{"choices":[{"message":{"role":"assistant","content":"hi there"}}]}"#
        XCTAssertEqual(try OpenAIProvider.parseText(status: 200, data: Data(json.utf8)), "hi there")
    }

    func testOpenAIParseHTTPError() {
        let json = #"{"error":{"message":"nope"}}"#
        XCTAssertThrowsError(try OpenAIProvider.parseText(status: 401, data: Data(json.utf8))) { error in
            guard case let LLMError.http(code, message) = error else { return XCTFail("expected http") }
            XCTAssertEqual(code, 401)
            XCTAssertEqual(message, "nope")
        }
    }

    // MARK: - Mock

    func testMockRecordsRequestsAndRepeatsLast() async throws {
        let mock = MockLLMProvider(responses: ["a", "b"])
        let r1 = try await mock.complete(.single(model: "m", system: nil, user: "1", maxTokens: 1))
        let r2 = try await mock.complete(.single(model: "m", system: nil, user: "2", maxTokens: 1))
        let r3 = try await mock.complete(.single(model: "m", system: nil, user: "3", maxTokens: 1))
        XCTAssertEqual([r1, r2, r3], ["a", "b", "b"])
        XCTAssertEqual(mock.receivedRequests.count, 3)
        XCTAssertEqual(mock.receivedRequests[0].messages.first?.content, "1")
    }
}
