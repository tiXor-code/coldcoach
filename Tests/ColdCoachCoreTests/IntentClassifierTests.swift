import XCTest
@testable import ColdCoachCore

final class IntentClassifierTests: XCTestCase {
    let classifier = IntentClassifier()

    func testObjections() {
        XCTAssertEqual(classifier.classify("Who is this?"), .objection)
        XCTAssertEqual(classifier.classify("I'm not interested."), .objection)
        XCTAssertEqual(classifier.classify("We already have a vendor."), .objection)
        XCTAssertEqual(classifier.classify("Not a good time."), .objection)
    }

    func testSendMeAnEmailIsObjectionNotBuyingSignal() {
        // "send me" appears in buying-signal markers, but the brush-off must win.
        XCTAssertEqual(classifier.classify("Just send me an email."), .objection)
    }

    func testBuyingSignals() {
        XCTAssertEqual(classifier.classify("How much does it cost?"), .buyingSignal)
        XCTAssertEqual(classifier.classify("What's the price?"), .buyingSignal)
        XCTAssertEqual(classifier.classify("Can you set up a demo?"), .buyingSignal)
    }

    func testQuestions() {
        XCTAssertEqual(classifier.classify("What do you actually do?"), .question)
        XCTAssertEqual(classifier.classify("How would that work for us?"), .question)
    }

    func testSmalltalkAndEmpty() {
        XCTAssertEqual(classifier.classify("Mm, okay."), .smalltalk)
        XCTAssertEqual(classifier.classify("Yeah that works."), .smalltalk)
        XCTAssertEqual(classifier.classify("   "), .none)
    }

    func testWarrantsCard() {
        XCTAssertTrue(IntentClassifier.warrantsCard(.objection))
        XCTAssertTrue(IntentClassifier.warrantsCard(.question))
        XCTAssertTrue(IntentClassifier.warrantsCard(.buyingSignal))
        XCTAssertFalse(IntentClassifier.warrantsCard(.smalltalk))
        XCTAssertFalse(IntentClassifier.warrantsCard(.none))
    }
}
