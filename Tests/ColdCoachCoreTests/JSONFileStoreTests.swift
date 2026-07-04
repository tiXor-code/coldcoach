import XCTest
@testable import ColdCoachCore

final class JSONFileStoreTests: XCTestCase {
    private var tmp: URL!
    private var store: JSONFileStore!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("coldcoach-tests-\(UUID().uuidString)")
        store = try JSONFileStore(baseDirectory: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testPlaybookRoundTripAndUpsert() throws {
        var pb = Playbook(offerSentence: "first")
        try store.savePlaybook(pb)
        XCTAssertEqual(try store.loadPlaybooks().count, 1)

        pb.offerSentence = "updated"
        try store.savePlaybook(pb)   // same id -> upsert
        let loaded = try store.loadPlaybooks()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.offerSentence, "updated")

        try store.deletePlaybook(id: pb.id)
        XCTAssertEqual(try store.loadPlaybooks().count, 0)
    }

    func testCallRoundTrip() throws {
        let call = CallRecord(
            audioMode: .speakerphoneMic,
            outcome: .booked,
            segments: [TranscriptSegment(role: .prospect, text: "hi", start: 0, end: 1)],
            coachingCards: [CoachingCard(kind: .objection, headline: "h", script: "s", rationale: "r")]
        )
        try store.saveCall(call)
        let loaded = try store.loadCalls()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.outcome, .booked)
        XCTAssertEqual(loaded.first?.segments.first?.text, "hi")

        try store.deleteCall(id: call.id)
        XCTAssertEqual(try store.loadCalls().count, 0)
    }

    func testSettingsDefaultsThenRoundTrip() throws {
        XCTAssertEqual(try store.loadSettings(), AppSettings.default)

        var s = AppSettings.default
        s.provider = .openai
        s.resetModelsForProvider()
        s.overlayOpacity = 0.5
        try store.saveSettings(s)

        let loaded = try store.loadSettings()
        XCTAssertEqual(loaded.provider, .openai)
        XCTAssertEqual(loaded.coachingModel, ProviderKind.openai.defaultCoachingModel)
        XCTAssertEqual(loaded.overlayOpacity, 0.5)
    }
}
