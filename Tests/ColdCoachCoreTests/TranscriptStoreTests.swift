import XCTest
@testable import ColdCoachCore

final class TranscriptStoreTests: XCTestCase {
    func testAppendAndRecent() {
        let store = TranscriptStore()
        for i in 0..<5 {
            store.upsert(TranscriptSegment(role: .rep, text: "line \(i)", start: Double(i), end: Double(i) + 1))
        }
        XCTAssertEqual(store.segments.count, 5)
        XCTAssertEqual(store.recent(2).map(\.text), ["line 3", "line 4"])
    }

    func testUpsertRefinesPartialToFinal() {
        let store = TranscriptStore()
        let id = UUID()
        let partial = TranscriptSegment(id: id, role: .prospect, text: "who is", start: 0, end: 1, isFinal: false)
        let final = TranscriptSegment(id: id, role: .prospect, text: "who is this", start: 0, end: 1.5, isFinal: true)

        XCTAssertFalse(store.upsert(partial))       // partial -> not "newly finalized"
        XCTAssertTrue(store.upsert(final))          // same id, now final
        XCTAssertEqual(store.segments.count, 1)
        XCTAssertEqual(store.segments[0].text, "who is this")
        XCTAssertEqual(store.segments[0].role, .prospect)
    }

    func testTrimToMax() {
        let store = TranscriptStore(maxSegments: 3)
        for i in 0..<6 {
            store.upsert(TranscriptSegment(role: .rep, text: "\(i)", start: Double(i), end: Double(i)))
        }
        XCTAssertEqual(store.segments.count, 3)
        XCTAssertEqual(store.segments.map(\.text), ["3", "4", "5"])
    }

    func testFinalizedFilter() {
        let store = TranscriptStore()
        store.upsert(TranscriptSegment(role: .rep, text: "final", start: 0, end: 1, isFinal: true))
        store.upsert(TranscriptSegment(role: .rep, text: "partial", start: 1, end: 2, isFinal: false))
        XCTAssertEqual(store.finalized.map(\.text), ["final"])
    }
}
