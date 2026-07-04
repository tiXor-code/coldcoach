import Foundation

/// Prompt construction for a single live coaching card, plus parsing of the reply.
public enum CoachingPrompts {
    public static let system = """
    You are a live cold-call coach whispering in the rep's ear. The prospect just said \
    something and the rep needs the next line NOW. Be instant, specific, and human.

    Return ONLY a JSON object (no prose, no code fences):
    { "headline": "<=6 words naming the moment", "script": "<one or two sentences the rep says next>", "rationale": "<=12 words on why" }

    Rules:
    - The "script" is spoken verbatim by the rep, so keep it natural and short.
    - Use the playbook when it fits; adapt it to what the prospect actually said.
    - Never invent facts about the prospect. No corporate filler.
    """

    /// Compact context so the coaching model responds fast.
    public static func userContext(
        offerSentence: String,
        playbook: Playbook,
        recentTurns: [TranscriptSegment],
        latestProspectLine: String,
        intent: Intent
    ) -> String {
        var lines: [String] = []
        lines.append("Offer: \(offerSentence)")
        lines.append("Detected moment: \(intent.rawValue)")

        if intent == .objection, !playbook.objectionCards.isEmpty {
            let cards = playbook.objectionCards
                .prefix(8)
                .map { "- \($0.trigger) -> \($0.response)" }
                .joined(separator: "\n")
            lines.append("Objection playbook:\n\(cards)")
        } else {
            let openers = playbook.openers.sorted { $0.weight > $1.weight }.prefix(3)
                .map { "- (\($0.signal)) \($0.text)" }.joined(separator: "\n")
            if !openers.isEmpty { lines.append("Top openers:\n\(openers)") }
            let qs = playbook.discoveryQuestions.prefix(5).map { "- \($0.text)" }.joined(separator: "\n")
            if !qs.isEmpty { lines.append("Discovery questions:\n\(qs)") }
        }

        let recent = recentTurns.suffix(6).map { seg -> String in
            let who = seg.role == .rep ? "Rep" : (seg.role == .prospect ? "Prospect" : "?")
            return "\(who): \(seg.text)"
        }.joined(separator: "\n")
        if !recent.isEmpty { lines.append("Recent transcript:\n\(recent)") }

        lines.append("Prospect just said: \"\(latestProspectLine)\"")
        lines.append("Give the rep their next line.")
        return lines.joined(separator: "\n\n")
    }

    public static func request(
        offerSentence: String,
        playbook: Playbook,
        recentTurns: [TranscriptSegment],
        latestProspectLine: String,
        intent: Intent,
        model: String
    ) -> LLMRequest {
        LLMRequest.single(
            model: model,
            system: system,
            user: userContext(
                offerSentence: offerSentence,
                playbook: playbook,
                recentTurns: recentTurns,
                latestProspectLine: latestProspectLine,
                intent: intent
            ),
            maxTokens: 300
        )
    }

    private struct GeneratedCard: Decodable {
        let headline: String?
        let script: String?
        let rationale: String?
    }

    /// Parse a coaching card from the model reply. Falls back to using the raw text as
    /// the script if the model did not return clean JSON, so a card always appears.
    public static func card(from raw: String, kind: CoachingKind) -> CoachingCard {
        if let g = try? JSONExtraction.decodeFirst(GeneratedCard.self, from: raw),
           let script = g.script, !script.trimmingCharacters(in: .whitespaces).isEmpty {
            return CoachingCard(
                kind: kind,
                headline: g.headline ?? kind.label,
                script: script,
                rationale: g.rationale ?? ""
            )
        }
        let fallback = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoachingCard(kind: kind, headline: kind.label, script: fallback, rationale: "")
    }
}
