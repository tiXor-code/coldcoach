import XCTest
@testable import ColdCoachCore

final class JSONExtractionTests: XCTestCase {
    func testExtractsFromProse() {
        let text = "Here you go: {\"a\": 1, \"b\": \"two\"} — enjoy!"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), "{\"a\": 1, \"b\": \"two\"}")
    }

    func testExtractsFromCodeFence() {
        let text = "```json\n{\"x\": true}\n```"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), "{\"x\": true}")
    }

    func testHandlesNestedBraces() {
        let text = "prefix {\"outer\": {\"inner\": [1, 2]}} suffix"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), "{\"outer\": {\"inner\": [1, 2]}}")
    }

    func testIgnoresBracesInsideStrings() {
        let text = "{\"note\": \"a } brace and a { brace\"}"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), text)
    }

    func testReturnsNilWhenNoObject() {
        XCTAssertNil(JSONExtraction.firstJSONObject(in: "no json here"))
    }

    struct Sample: Decodable, Equatable { let name: String; let count: Int }

    func testDecodeFirst() throws {
        let text = "result -> {\"name\": \"ok\", \"count\": 3}"
        let decoded = try JSONExtraction.decodeFirst(Sample.self, from: text)
        XCTAssertEqual(decoded, Sample(name: "ok", count: 3))
    }

    func testDecodeFirstThrowsWhenMissing() {
        XCTAssertThrowsError(try JSONExtraction.decodeFirst(Sample.self, from: "nope"))
    }
}
