import XCTest
@testable import ColdCoachCore

final class RoleAssignerTests: XCTestCase {
    func testPauseGapToggling() {
        let assigner = RoleAssigner(gapThreshold: 0.8, firstSpeaker: .rep)
        let segs = [
            TranscriptSegment(role: .unknown, text: "hi there", start: 0.0, end: 2.0),
            TranscriptSegment(role: .unknown, text: "still me", start: 2.2, end: 3.0),
            TranscriptSegment(role: .unknown, text: "who is this", start: 4.0, end: 5.0),
            TranscriptSegment(role: .unknown, text: "still them", start: 5.1, end: 6.0),
        ]
        XCTAssertEqual(assigner.assign(segs).map(\.role), [.rep, .rep, .prospect, .prospect])
    }

    func testEmptyStaysEmpty() {
        XCTAssertTrue(RoleAssigner().assign([]).isEmpty)
    }

    func testStreamingNextRole() {
        let assigner = RoleAssigner(gapThreshold: 0.8)
        let first = TranscriptSegment(role: .rep, text: "a", start: 0, end: 1)
        let same = TranscriptSegment(role: .unknown, text: "b", start: 1.2, end: 2)   // gap 0.2
        let switched = TranscriptSegment(role: .unknown, text: "c", start: 3, end: 4) // gap 1.0
        XCTAssertEqual(assigner.nextRole(previous: nil, current: first), .rep)
        XCTAssertEqual(assigner.nextRole(previous: first, current: same), .rep)
        XCTAssertEqual(assigner.nextRole(previous: first, current: switched), .prospect)
    }
}
