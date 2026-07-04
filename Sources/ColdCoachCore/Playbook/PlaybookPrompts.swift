import Foundation

/// Prompt construction and response schema for playbook generation.
public enum PlaybookPrompts {
    public static let system = """
    You are a B2B cold-calling coach. From a one-sentence description of what the rep sells \
    and to whom, produce a concise, practical playbook.

    Return ONLY a JSON object (no prose, no code fences) matching exactly this shape:
    {
      "openers": [ { "signal": "<a real buying/context signal>", "text": "<the opening line>" } ],
      "discoveryQuestions": [ "<question>" ],
      "objectionCards": [ { "trigger": "<objection as the prospect says it>", "response": "<what the rep says back>" } ]
    }

    Rules:
    - 3 to 5 openers, each tied to a distinct, realistic signal (a trigger event, role, or pain).
    - 4 to 6 discovery questions that surface pain and qualify.
    - 5 to 8 objection cards covering the most common real objections for this offer \
      (price, timing, incumbent, authority, "not interested", "send an email").
    - Every line must be short enough to say out loud on a live call.
    - Write in the rep's voice: natural, specific, no corporate filler.
    """

    public static func user(offerSentence: String, contextNotes: String) -> String {
        var out = "Offer (one sentence): \(offerSentence)"
        let notes = contextNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            out += "\n\nAdditional context:\n\(notes)"
        }
        return out
    }

    public static func request(offerSentence: String, contextNotes: String, model: String) -> LLMRequest {
        LLMRequest.single(
            model: model,
            system: system,
            user: user(offerSentence: offerSentence, contextNotes: contextNotes),
            maxTokens: 4000
        )
    }

    /// The JSON shape the model is asked to return.
    public struct Generated: Decodable {
        public struct GOpener: Decodable { public let signal: String; public let text: String }
        public struct GObjection: Decodable { public let trigger: String; public let response: String }
        public let openers: [GOpener]
        public let discoveryQuestions: [String]
        public let objectionCards: [GObjection]
    }
}
