import Foundation
import XCTest
@testable import ColdCoachCore

/// Simplified fixture line: role + text + timing (no UUIDs to author by hand).
struct MockCallLine: Decodable {
    let role: String
    let text: String
    let start: Double
    let end: Double

    var role_: Role { Role(rawValue: role) ?? .unknown }
    var segment: TranscriptSegment {
        TranscriptSegment(role: role_, text: text, start: start, end: end, isFinal: true)
    }
}

enum TestSupport {
    /// Load the bundled mock cold-call transcript.
    static func loadMockCall() throws -> [TranscriptSegment] {
        let url = try mockCallURL()
        let data = try Data(contentsOf: url)
        let lines = try JSONDecoder().decode([MockCallLine].self, from: data)
        return lines.map(\.segment)
    }

    private static func mockCallURL() throws -> URL {
        if let url = Bundle.module.url(forResource: "mock_call", withExtension: "json", subdirectory: "Fixtures") {
            return url
        }
        if let url = Bundle.module.url(forResource: "mock_call", withExtension: "json") {
            return url
        }
        throw XCTSkip("mock_call.json fixture not found in test bundle")
    }

    static func samplePlaybook() -> Playbook {
        Playbook(
            offerSentence: "We help B2B sales teams book more meetings with AI live-call coaching.",
            contextNotes: "",
            openers: [
                Opener(signal: "hiring SDRs", text: "Saw you're hiring reps, so ramp is probably top of mind."),
                Opener(signal: "generic", text: "Quick one since I caught you cold.")
            ],
            discoveryQuestions: [
                DiscoveryQuestion(text: "How are you ramping new reps today?")
            ],
            objectionCards: [
                ObjectionCard(trigger: "already have a vendor", response: "Makes sense. What would have to be true to switch?"),
                ObjectionCard(trigger: "not interested", response: "Fair. If I'm wrong give me 20 seconds to prove it.")
            ]
        )
    }

    /// A scripted coaching-card JSON the MockLLMProvider can return for any request.
    static let coachingCardJSON = #"{"headline":"Test moment","script":"Here is the line to say.","rationale":"builds trust"}"#

    /// A scripted playbook JSON (wrapped in prose to exercise tolerant extraction).
    static let playbookJSON = """
    Sure! Here is your playbook:
    ```json
    {
      "openers": [
        {"signal": "just raised funding", "text": "Congrats on the raise — usually means hiring is about to spike."},
        {"signal": "generic", "text": "I'll be quick since I caught you cold."}
      ],
      "discoveryQuestions": ["How are you booking meetings today?", "What's your ramp time for a new rep?"],
      "objectionCards": [
        {"trigger": "we already have a tool", "response": "Totally — what would make you look at another?"},
        {"trigger": "not interested", "response": "Fair enough. Twenty seconds to prove it's worth it?"}
      ]
    }
    ```
    Good luck!
    """
}
