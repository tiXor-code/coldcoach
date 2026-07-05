import XCTest
@testable import ColdCoachCore

final class CoachingEngineTests: XCTestCase {
    private func prospect(_ text: String, start: Double, end: Double, final: Bool = true) -> TranscriptSegment {
        TranscriptSegment(role: .prospect, text: text, start: start, end: end, isFinal: final)
    }

    func testFiresOnProspectObjection() {
        let engine = CoachingEngine()
        let pb = TestSupport.samplePlaybook()
        let d = engine.decide(
            segment: prospect("I'm not interested.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"
        )
        XCTAssertNotNil(d)
        XCTAssertEqual(d?.kind, .objection)
        XCTAssertEqual(d?.request.model, "cm")
        XCTAssertEqual(d?.request.maxTokens, 300)
        XCTAssertNotNil(d?.request.system)
    }

    func testIgnoresRepSmalltalkAndPartials() {
        let engine = CoachingEngine()
        let pb = TestSupport.samplePlaybook()
        XCTAssertNil(engine.decide(
            segment: TranscriptSegment(role: .rep, text: "not interested", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
        XCTAssertNil(engine.decide(
            segment: prospect("Mm, okay.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
        XCTAssertNil(engine.decide(
            segment: prospect("How much?", start: 0, end: 2, final: false),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
    }

    func testDebounceSuppressesRapidSecondCard() {
        let engine = CoachingEngine(config: .init(cooldown: 6.0))
        let pb = TestSupport.samplePlaybook()
        let ctx: (TranscriptSegment) -> CoachingEngine.Decision? = {
            engine.decide(segment: $0, playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm")
        }
        XCTAssertNotNil(ctx(prospect("Who is this?", start: 0, end: 2)))            // fires, lastFire=2
        XCTAssertNil(ctx(prospect("Not a good time.", start: 3, end: 5)))            // 5-2=3 < 6 -> suppressed
        XCTAssertNotNil(ctx(prospect("We already have a vendor.", start: 8, end: 9))) // 9-2=7 >= 6 -> fires
    }

    func testCoachReturnsCardViaProvider() async throws {
        let provider = MockLLMProvider(response: TestSupport.coachingCardJSON)
        let engine = CoachingEngine()
        let pb = TestSupport.samplePlaybook()
        let card = try await engine.coach(
            segment: prospect("We already have a vendor.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm", provider: provider
        )
        XCTAssertEqual(card?.kind, .objection)
        XCTAssertEqual(card?.script, "Here is the line to say.")
        XCTAssertEqual(card?.headline, "Test moment")
        XCTAssertEqual(provider.receivedRequests.count, 1)
    }

    func testCoachReturnsNilWhenNoTrigger() async throws {
        let provider = MockLLMProvider(response: TestSupport.coachingCardJSON)
        let engine = CoachingEngine()
        let pb = TestSupport.samplePlaybook()
        let card = try await engine.coach(
            segment: prospect("Mm, okay.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm", provider: provider
        )
        XCTAssertNil(card)
        XCTAssertEqual(provider.receivedRequests.count, 0)
    }

    // MARK: - Mode A (requireProspectRole == false): coach on content, not role

    func testModeACoachesOnObjectionFromNonProspectRole() {
        let engine = CoachingEngine(config: .init(requireProspectRole: false))
        let pb = TestSupport.samplePlaybook()
        // A mixed-mic segment tagged .rep (Mode A's role heuristic is unreliable) still fires
        // because the content is an objection.
        let d = engine.decide(
            segment: TranscriptSegment(role: .rep, text: "We already have a vendor.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm")
        XCTAssertNotNil(d)
        XCTAssertEqual(d?.kind, .objection)
    }

    func testModeAStillIgnoresSmalltalkAndPartials() {
        let engine = CoachingEngine(config: .init(requireProspectRole: false))
        let pb = TestSupport.samplePlaybook()
        XCTAssertNil(engine.decide(
            segment: TranscriptSegment(role: .rep, text: "Mm, okay.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
        XCTAssertNil(engine.decide(
            segment: TranscriptSegment(role: .unknown, text: "How much?", start: 0, end: 2, isFinal: false),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
    }

    func testModeBDefaultStillRequiresProspectRole() {
        let engine = CoachingEngine() // default requireProspectRole == true
        let pb = TestSupport.samplePlaybook()
        XCTAssertNil(engine.decide(
            segment: TranscriptSegment(role: .rep, text: "We already have a vendor.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
        XCTAssertNotNil(engine.decide(
            segment: TranscriptSegment(role: .prospect, text: "We already have a vendor.", start: 0, end: 2),
            playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm"))
    }
}
