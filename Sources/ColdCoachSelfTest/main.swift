import Foundation
import ColdCoachCore

// Dependency-free assertion runner for ColdCoachCore.
// Mirrors the XCTest suite so the core can be verified without Xcode/XCTest.
// Usage: swift run coldcoach-selftest   (exit code 0 = all pass)

var checks = 0
var failures = 0

func ok(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}
func eq<T: Equatable>(_ a: T, _ b: T, _ message: String) {
    checks += 1
    if a != b { failures += 1; print("FAIL: \(message) — got \(a), expected \(b)") }
}
func approx(_ a: Double, _ b: Double, _ message: String, tol: Double = 1e-9) {
    checks += 1
    if abs(a - b) > tol { failures += 1; print("FAIL: \(message) — got \(a), expected \(b)") }
}
func throwsError(_ message: String, _ body: () throws -> Void) {
    checks += 1
    do { try body(); failures += 1; print("FAIL: \(message) — expected an error") } catch { /* expected */ }
}

let coachingCardJSON = #"{"headline":"Test moment","script":"Here is the line to say.","rationale":"builds trust"}"#

func samplePlaybook() -> Playbook {
    Playbook(
        offerSentence: "We help B2B sales teams book more meetings with AI live-call coaching.",
        openers: [Opener(signal: "hiring SDRs", text: "Saw you're hiring reps.")],
        discoveryQuestions: [DiscoveryQuestion(text: "How are you ramping new reps today?")],
        objectionCards: [ObjectionCard(trigger: "already have a vendor", response: "What would make you switch?")]
    )
}

// MARK: - JSON extraction
do {
    eq(JSONExtraction.firstJSONObject(in: "x {\"a\":1} y"), "{\"a\":1}", "extract from prose")
    eq(JSONExtraction.firstJSONObject(in: "```json\n{\"x\":true}\n```"), "{\"x\":true}", "extract from fence")
    eq(JSONExtraction.firstJSONObject(in: "p {\"o\":{\"i\":[1,2]}} s"), "{\"o\":{\"i\":[1,2]}}", "nested braces")
    ok(JSONExtraction.firstJSONObject(in: "{\"n\":\"a } b { c\"}") == "{\"n\":\"a } b { c\"}", "braces in string")
    ok(JSONExtraction.firstJSONObject(in: "no json") == nil, "nil when no object")
}

// MARK: - Intent classifier
do {
    let c = IntentClassifier()
    eq(c.classify("Who is this?"), .objection, "objection: who is this")
    eq(c.classify("Just send me an email."), .objection, "send-me-an-email is objection not buying")
    eq(c.classify("How much does it cost?"), .buyingSignal, "buying: how much")
    eq(c.classify("What do you actually do?"), .question, "question")
    eq(c.classify("Mm, okay."), .smalltalk, "smalltalk")
    eq(c.classify("   "), Intent.none, "empty -> none")
    ok(IntentClassifier.warrantsCard(.objection) && !IntentClassifier.warrantsCard(.smalltalk), "warrantsCard")
}

// MARK: - Claude wire format
do {
    let req = LLMRequest(model: "claude-haiku-4-5", system: "S1",
                         messages: [LLMMessage(role: .system, content: "S2"), LLMMessage(role: .user, content: "hi")],
                         maxTokens: 100)
    let data = try ClaudeProvider.encodeBody(req)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    eq(obj["model"] as? String, "claude-haiku-4-5", "claude model")
    eq(obj["max_tokens"] as? Int, 100, "claude max_tokens")
    let sys = obj["system"] as? String ?? ""
    ok(sys.contains("S1") && sys.contains("S2"), "claude system lifted")
    let msgs = obj["messages"] as! [[String: Any]]
    eq(msgs.count, 1, "claude messages user-only")
    eq(msgs[0]["role"] as? String, "user", "claude first role user")

    let good = #"{"content":[{"type":"text","text":"Hello "},{"type":"thinking"},{"type":"text","text":"world"}],"stop_reason":"end_turn"}"#
    eq(try ClaudeProvider.parseText(status: 200, data: Data(good.utf8)), "Hello world", "claude parse joins text, drops thinking")
    throwsError("claude refusal throws") {
        _ = try ClaudeProvider.parseText(status: 200, data: Data(#"{"content":[],"stop_reason":"refusal"}"#.utf8))
    }
    do {
        _ = try ClaudeProvider.parseText(status: 400, data: Data(#"{"error":{"message":"bad model"}}"#.utf8))
        failures += 1; checks += 1; print("FAIL: claude http error should throw")
    } catch let LLMError.http(code, msg) {
        checks += 1; eq(code, 400, "claude http code"); eq(msg, "bad model", "claude http message")
    } catch { checks += 1; failures += 1; print("FAIL: claude http wrong error \(error)") }
}

// MARK: - OpenAI wire format
do {
    let req = LLMRequest(model: "gpt-4o-mini", system: "S", messages: [LLMMessage(role: .user, content: "hi")], maxTokens: 50)
    let data = try OpenAIProvider.encodeBody(req)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let msgs = obj["messages"] as! [[String: Any]]
    eq(msgs.count, 2, "openai message count")
    eq(msgs[0]["role"] as? String, "system", "openai system first")
    eq(msgs[1]["role"] as? String, "user", "openai user second")
    eq(try OpenAIProvider.parseText(status: 200, data: Data(#"{"choices":[{"message":{"content":"hi there"}}]}"#.utf8)),
       "hi there", "openai parse")
}

// MARK: - Mock provider
do {
    let mock = MockLLMProvider(responses: ["a", "b"])
    let r1 = try await mock.complete(.single(model: "m", system: nil, user: "1", maxTokens: 1))
    let r2 = try await mock.complete(.single(model: "m", system: nil, user: "2", maxTokens: 1))
    let r3 = try await mock.complete(.single(model: "m", system: nil, user: "3", maxTokens: 1))
    eq([r1, r2, r3], ["a", "b", "b"], "mock repeats last")
    eq(mock.receivedRequests.count, 3, "mock records requests")
}

// MARK: - Playbook parse / generate / weighting
let playbookJSON = """
Here you go:
```json
{ "openers": [{"signal":"just raised funding","text":"Congrats on the raise."},{"signal":"generic","text":"Quick one."}],
  "discoveryQuestions": ["How do you book meetings today?","Ramp time for a rep?"],
  "objectionCards": [{"trigger":"we already have a tool","response":"What would make you switch?"},{"trigger":"not interested","response":"20 seconds to prove it?"}] }
```
"""
do {
    let pb = try PlaybookService.playbook(from: playbookJSON, offerSentence: "We sell X", contextNotes: "notes")
    eq(pb.offerSentence, "We sell X", "playbook offer")
    eq(pb.openers.count, 2, "playbook openers")
    eq(pb.discoveryQuestions.count, 2, "playbook questions")
    eq(pb.objectionCards.count, 2, "playbook objections")
    ok(pb.openers.allSatisfy { $0.weight == 1.0 }, "playbook default weights")

    let svc = PlaybookService()
    let provider = MockLLMProvider(response: playbookJSON)
    let generated = try await svc.generate(offerSentence: "We sell X", using: provider, model: "claude-opus-4-8")
    eq(generated.openers.count, 2, "generate openers")
    eq(provider.receivedRequests.first?.model, "claude-opus-4-8", "generate uses playbook model")
    eq(provider.receivedRequests.first?.maxTokens, 4000, "generate max tokens")

    var emptyOfferThrew = false
    do { _ = try await svc.generate(offerSentence: "  ", using: provider, model: "m") }
    catch { emptyOfferThrew = true }
    ok(emptyOfferThrew, "generate empty offer throws")

    // Weighting
    let opener = Opener(signal: "s", text: "t", weight: 1.0)
    let objection = ObjectionCard(trigger: "x", response: "y", weight: 1.0)
    var wpb = Playbook(offerSentence: "o", openers: [opener], objectionCards: [objection])
    wpb = svc.applyOutcome(OutcomeSignal(outcome: .booked, usedOpenerID: opener.id), to: wpb)
    approx(wpb.openers[0].weight, 1.2, "win bumps opener")
    wpb = svc.applyOutcome(OutcomeSignal(outcome: .notInterested, usedOpenerID: opener.id), to: wpb)
    approx(wpb.openers[0].weight, 0.96, "loss decays opener")
    wpb = svc.applyOutcome(OutcomeSignal(outcome: .booked, resolvedObjectionIDs: [objection.id]), to: wpb)
    approx(wpb.objectionCards[0].weight, 1.2, "resolved objection bump")

    // Clamp
    var cpb = Playbook(offerSentence: "o", openers: [Opener(signal: "s", text: "t", weight: 4.5)])
    cpb = svc.applyOutcome(OutcomeSignal(outcome: .booked, usedOpenerID: cpb.openers[0].id), to: cpb)
    approx(cpb.openers[0].weight, PlaybookService.maxWeight, "clamp max")
}

// MARK: - Coaching engine
do {
    let pb = samplePlaybook()
    let engine = CoachingEngine()
    func prospect(_ t: String, _ s: Double, _ e: Double, final: Bool = true) -> TranscriptSegment {
        TranscriptSegment(role: .prospect, text: t, start: s, end: e, isFinal: final)
    }

    let d = engine.decide(segment: prospect("I'm not interested.", 0, 2),
                          playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm")
    ok(d != nil, "fires on objection")
    eq(d?.kind, .objection, "kind objection")
    eq(d?.request.model, "cm", "coaching model")
    eq(d?.request.maxTokens, 300, "coaching max tokens")

    let e2 = CoachingEngine()
    ok(e2.decide(segment: TranscriptSegment(role: .rep, text: "not interested", start: 0, end: 2),
                 playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") == nil, "ignores rep")
    ok(e2.decide(segment: prospect("Mm, okay.", 0, 2),
                 playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") == nil, "ignores smalltalk")
    ok(e2.decide(segment: prospect("How much?", 0, 2, final: false),
                 playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") == nil, "ignores partial")

    let e3 = CoachingEngine(config: .init(cooldown: 6.0))
    ok(e3.decide(segment: prospect("Who is this?", 0, 2), playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") != nil, "debounce: first fires")
    ok(e3.decide(segment: prospect("Not a good time.", 3, 5), playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") == nil, "debounce: second suppressed")
    ok(e3.decide(segment: prospect("We already have a vendor.", 8, 9), playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm") != nil, "debounce: after cooldown fires")

    let provider = MockLLMProvider(response: coachingCardJSON)
    let e4 = CoachingEngine()
    let card = try await e4.coach(segment: prospect("We already have a vendor.", 0, 2),
                                  playbook: pb, offerSentence: pb.offerSentence, recentTurns: [], coachingModel: "cm", provider: provider)
    eq(card?.kind, .objection, "coach card kind")
    eq(card?.script, "Here is the line to say.", "coach card script")
}

// MARK: - Transcript store
do {
    let store = TranscriptStore(maxSegments: 3)
    for i in 0..<6 { store.upsert(TranscriptSegment(role: .rep, text: "\(i)", start: Double(i), end: Double(i))) }
    eq(store.segments.count, 3, "store trims")
    eq(store.segments.map(\.text), ["3", "4", "5"], "store keeps newest")

    let s2 = TranscriptStore()
    let id = UUID()
    ok(s2.upsert(TranscriptSegment(id: id, role: .prospect, text: "who is", start: 0, end: 1, isFinal: false)) == false, "partial not finalized")
    ok(s2.upsert(TranscriptSegment(id: id, role: .prospect, text: "who is this", start: 0, end: 1.5, isFinal: true)) == true, "refine to final")
    eq(s2.segments.count, 1, "upsert same id")
    eq(s2.segments[0].text, "who is this", "upsert updates text")
}

// MARK: - Role assigner (Mode A)
do {
    let assigner = RoleAssigner(gapThreshold: 0.8, firstSpeaker: .rep)
    let segs = [
        TranscriptSegment(role: .unknown, text: "hi there", start: 0.0, end: 2.0),
        TranscriptSegment(role: .unknown, text: "still me", start: 2.2, end: 3.0),   // gap 0.2 -> same (rep)
        TranscriptSegment(role: .unknown, text: "who is this", start: 4.0, end: 5.0), // gap 1.0 -> toggle (prospect)
        TranscriptSegment(role: .unknown, text: "still them", start: 5.1, end: 6.0),  // gap 0.1 -> same (prospect)
    ]
    let roles = assigner.assign(segs).map(\.role)
    eq(roles, [.rep, .rep, .prospect, .prospect], "role assigner pause-gap toggling")
}

// MARK: - JSON file store
do {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("coldcoach-selftest-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tmp) }
    let store = try JSONFileStore(baseDirectory: tmp)
    var pb = Playbook(offerSentence: "first")
    try store.savePlaybook(pb)
    eq(try store.loadPlaybooks().count, 1, "store save playbook")
    pb.offerSentence = "updated"
    try store.savePlaybook(pb)
    eq(try store.loadPlaybooks().count, 1, "store upsert playbook")
    eq(try store.loadPlaybooks().first?.offerSentence, "updated", "store playbook updated")
    try store.deletePlaybook(id: pb.id)
    eq(try store.loadPlaybooks().count, 0, "store delete playbook")

    eq(try store.loadSettings(), AppSettings.default, "store default settings")
    var s = AppSettings.default; s.provider = .openai; s.resetModelsForProvider()
    try store.saveSettings(s)
    eq(try store.loadSettings().coachingModel, ProviderKind.openai.defaultCoachingModel, "store settings round trip")
}

// MARK: - Mock-call integration
do {
    let here = URL(fileURLWithPath: #filePath)
    let repoRoot = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let fixtureURL = repoRoot.appendingPathComponent("Tests/ColdCoachCoreTests/Fixtures/mock_call.json")
    struct Line: Decodable { let role: String; let text: String; let start: Double; let end: Double }
    let data = try Data(contentsOf: fixtureURL)
    let lines = try JSONDecoder().decode([Line].self, from: data)
    let segments = lines.map { TranscriptSegment(role: Role(rawValue: $0.role) ?? .unknown, text: $0.text, start: $0.start, end: $0.end, isFinal: true) }
    ok(!segments.isEmpty, "fixture loads")

    let engine = CoachingEngine()
    let store = TranscriptStore()
    let provider = MockLLMProvider(response: coachingCardJSON)
    let pb = samplePlaybook()
    var cards: [CoachingCard] = []
    for seg in segments {
        store.upsert(seg)
        guard seg.role == .prospect else { continue }
        if let card = try await engine.coach(segment: seg, playbook: pb, offerSentence: pb.offerSentence,
                                              recentTurns: store.recent(6), coachingModel: "cm", provider: provider) {
            cards.append(card)
        }
    }
    eq(cards.count, 3, "integration: 3 cards")
    eq(cards.map(\.kind), [.objection, .objection, .buyingSignal], "integration: card kinds")
}

// MARK: - Summary
if failures == 0 {
    print("ALL PASS — \(checks) checks")
    exit(0)
} else {
    print("\(failures) FAILURES / \(checks) checks")
    exit(1)
}
