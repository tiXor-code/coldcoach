import XCTest
@testable import ColdCoachCore

/// End-to-end pass over a scripted cold call: transcript -> store -> engine -> mock LLM.
/// Proves the coaching brain fires exactly on the seeded objections/buying-signal,
/// respects debounce, and ignores rep turns and smalltalk — with no audio or network.
final class MockCallIntegrationTests: XCTestCase {
    func testMockCallProducesExpectedCoachingCards() async throws {
        let segments = try TestSupport.loadMockCall()
        XCTAssertFalse(segments.isEmpty, "fixture should load")

        let engine = CoachingEngine()
        let store = TranscriptStore()
        let provider = MockLLMProvider(response: TestSupport.coachingCardJSON)
        let playbook = TestSupport.samplePlaybook()

        var cards: [CoachingCard] = []
        for segment in segments {
            store.upsert(segment)
            guard segment.role == .prospect else { continue }
            if let card = try await engine.coach(
                segment: segment,
                playbook: playbook,
                offerSentence: playbook.offerSentence,
                recentTurns: store.recent(6),
                coachingModel: "cm",
                provider: provider
            ) {
                cards.append(card)
            }
        }

        // Expected: "Who is this?" (objection), "We already have a vendor." (objection),
        // "How much does it cost?" (buying signal). "Not a good time." is suppressed by
        // debounce; "Mm, okay." and "Yeah that works." are smalltalk.
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards.map(\.kind), [.objection, .objection, .buyingSignal])
        XCTAssertEqual(provider.receivedRequests.count, 3)
    }
}
