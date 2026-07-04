import XCTest
@testable import ColdCoachCore

final class PlaybookServiceTests: XCTestCase {
    func testParsePlaybookFromWrappedJSON() throws {
        let pb = try PlaybookService.playbook(from: TestSupport.playbookJSON, offerSentence: "We sell X", contextNotes: "notes")
        XCTAssertEqual(pb.offerSentence, "We sell X")
        XCTAssertEqual(pb.contextNotes, "notes")
        XCTAssertEqual(pb.openers.count, 2)
        XCTAssertEqual(pb.discoveryQuestions.count, 2)
        XCTAssertEqual(pb.objectionCards.count, 2)
        XCTAssertTrue(pb.openers.allSatisfy { $0.weight == 1.0 })
        XCTAssertTrue(pb.objectionCards.allSatisfy { $0.weight == 1.0 })
        XCTAssertEqual(pb.openers.first?.signal, "just raised funding")
    }

    func testGenerateCallsProviderWithPlaybookModel() async throws {
        let provider = MockLLMProvider(response: TestSupport.playbookJSON)
        let svc = PlaybookService()
        let pb = try await svc.generate(offerSentence: "We sell X", using: provider, model: "claude-opus-4-8")
        XCTAssertEqual(pb.openers.count, 2)
        XCTAssertEqual(provider.receivedRequests.count, 1)
        XCTAssertEqual(provider.receivedRequests[0].model, "claude-opus-4-8")
        XCTAssertNotNil(provider.receivedRequests[0].system)
        XCTAssertEqual(provider.receivedRequests[0].maxTokens, 4000)
    }

    func testGenerateEmptyOfferThrows() async {
        let provider = MockLLMProvider(response: TestSupport.playbookJSON)
        let svc = PlaybookService()
        do {
            _ = try await svc.generate(offerSentence: "   ", using: provider, model: "m")
            XCTFail("expected throw")
        } catch {
            // expected
        }
    }

    func testApplyOutcomeBumpsAndDecays() {
        let svc = PlaybookService()
        let opener = Opener(signal: "s", text: "t", weight: 1.0)
        let objection = ObjectionCard(trigger: "x", response: "y", weight: 1.0)
        var pb = Playbook(offerSentence: "o", openers: [opener], objectionCards: [objection])

        // Win bumps the used opener by 1.2x.
        pb = svc.applyOutcome(OutcomeSignal(outcome: .booked, usedOpenerID: opener.id), to: pb)
        XCTAssertEqual(pb.openers[0].weight, 1.2, accuracy: 1e-9)

        // Loss decays it by 0.8x (1.2 -> 0.96).
        pb = svc.applyOutcome(OutcomeSignal(outcome: .notInterested, usedOpenerID: opener.id), to: pb)
        XCTAssertEqual(pb.openers[0].weight, 0.96, accuracy: 1e-9)

        // Resolved objection bumps; failed decays.
        pb = svc.applyOutcome(OutcomeSignal(outcome: .booked, resolvedObjectionIDs: [objection.id]), to: pb)
        XCTAssertEqual(pb.objectionCards[0].weight, 1.2, accuracy: 1e-9)
        pb = svc.applyOutcome(OutcomeSignal(outcome: .objectionUnresolved, failedObjectionIDs: [objection.id]), to: pb)
        XCTAssertEqual(pb.objectionCards[0].weight, 0.96, accuracy: 1e-9)
    }

    func testApplyOutcomeClampsWeights() {
        let svc = PlaybookService()
        let hot = Opener(signal: "s", text: "t", weight: 4.5)
        let cold = Opener(signal: "s2", text: "t2", weight: 0.12)
        var pb = Playbook(offerSentence: "o", openers: [hot, cold])

        // 4.5 * 1.2 = 5.4 -> clamped to 5.0
        pb = svc.applyOutcome(OutcomeSignal(outcome: .booked, usedOpenerID: hot.id), to: pb)
        XCTAssertEqual(pb.openers[0].weight, PlaybookService.maxWeight, accuracy: 1e-9)

        // 0.12 * 0.8 = 0.096 -> clamped to 0.1
        pb = svc.applyOutcome(OutcomeSignal(outcome: .notInterested, usedOpenerID: cold.id), to: pb)
        XCTAssertEqual(pb.openers[1].weight, PlaybookService.minWeight, accuracy: 1e-9)
    }
}
