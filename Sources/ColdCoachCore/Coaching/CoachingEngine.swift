import Foundation

/// Decides WHEN to surface a coaching card and builds the request to produce it.
///
/// Debouncing uses the transcript timeline (`segment.end`) rather than wall-clock time,
/// so behavior is fully deterministic and testable from a scripted transcript.
public final class CoachingEngine {
    public struct Config: Sendable {
        /// Minimum seconds (in call time) between two cards.
        public var cooldown: TimeInterval
        /// Minimum words in a prospect turn before it can trigger (objections bypass this).
        public var minWords: Int
        /// When true (Mode B: system + mic gives reliable per-stream roles) only prospect
        /// turns coach. When false (Mode A: a mixed mono mic that cannot be reliably
        /// diarized by pauses) any FINAL segment whose intent warrants a card can fire,
        /// so cards are driven by content instead of a fragile role heuristic.
        public var requireProspectRole: Bool

        public init(cooldown: TimeInterval = 6.0, minWords: Int = 2, requireProspectRole: Bool = true) {
            self.cooldown = cooldown
            self.minWords = minWords
            self.requireProspectRole = requireProspectRole
        }
    }

    public struct Decision: Sendable {
        public let kind: CoachingKind
        public let intent: Intent
        public let request: LLMRequest
        public let latestLine: String
    }

    private let classifier: IntentClassifier
    private let config: Config
    private var lastFireEnd: TimeInterval?

    public init(classifier: IntentClassifier = IntentClassifier(), config: Config = Config()) {
        self.classifier = classifier
        self.config = config
    }

    /// Clear debounce state at the start of a new call.
    public func reset() { lastFireEnd = nil }

    /// Pure trigger decision. Returns a ready-to-send request, or nil if no card is warranted.
    /// Mutates internal debounce state only when it decides to fire.
    public func decide(
        segment: TranscriptSegment,
        playbook: Playbook,
        offerSentence: String,
        recentTurns: [TranscriptSegment],
        coachingModel: String
    ) -> Decision? {
        guard segment.isFinal else { return nil }
        if config.requireProspectRole, segment.role != .prospect { return nil }

        let intent = classifier.classify(segment.text)
        guard IntentClassifier.warrantsCard(intent) else { return nil }

        let wordCount = segment.text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        if wordCount < config.minWords, intent != .objection { return nil }

        if let last = lastFireEnd, segment.end - last < config.cooldown { return nil }

        let request = CoachingPrompts.request(
            offerSentence: offerSentence,
            playbook: playbook,
            recentTurns: recentTurns,
            latestProspectLine: segment.text,
            intent: intent,
            model: coachingModel
        )
        lastFireEnd = segment.end
        return Decision(
            kind: IntentClassifier.kind(for: intent),
            intent: intent,
            request: request,
            latestLine: segment.text
        )
    }

    /// Convenience used by the app: decide, call the provider, and parse a card.
    public func coach(
        segment: TranscriptSegment,
        playbook: Playbook,
        offerSentence: String,
        recentTurns: [TranscriptSegment],
        coachingModel: String,
        provider: LLMProvider
    ) async throws -> CoachingCard? {
        guard let decision = decide(
            segment: segment,
            playbook: playbook,
            offerSentence: offerSentence,
            recentTurns: recentTurns,
            coachingModel: coachingModel
        ) else { return nil }

        let raw = try await provider.complete(decision.request)
        return CoachingPrompts.card(from: raw, kind: decision.kind)
    }
}
