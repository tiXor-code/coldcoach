import Foundation

/// A logged call result used to nudge playbook weights.
public struct OutcomeSignal: Sendable {
    public var outcome: CallOutcome
    /// The opener the rep actually used (if any).
    public var usedOpenerID: UUID?
    /// Objections that came up and were turned around.
    public var resolvedObjectionIDs: [UUID]
    /// Objections that came up and were not overcome.
    public var failedObjectionIDs: [UUID]

    public init(
        outcome: CallOutcome,
        usedOpenerID: UUID? = nil,
        resolvedObjectionIDs: [UUID] = [],
        failedObjectionIDs: [UUID] = []
    ) {
        self.outcome = outcome
        self.usedOpenerID = usedOpenerID
        self.resolvedObjectionIDs = resolvedObjectionIDs
        self.failedObjectionIDs = failedObjectionIDs
    }
}

/// Generates playbooks from an offer sentence and re-weights them from call outcomes.
public struct PlaybookService: Sendable {
    public static let minWeight = 0.1
    public static let maxWeight = 5.0

    public init() {}

    // MARK: - Generation

    /// Generate a fresh playbook from a one-sentence offer using `provider`.
    public func generate(
        offerSentence: String,
        contextNotes: String = "",
        using provider: LLMProvider,
        model: String
    ) async throws -> Playbook {
        let trimmed = offerSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LLMError.decoding("Offer sentence is empty")
        }
        let request = PlaybookPrompts.request(offerSentence: trimmed, contextNotes: contextNotes, model: model)
        let raw = try await provider.complete(request)
        return try Self.playbook(from: raw, offerSentence: trimmed, contextNotes: contextNotes)
    }

    /// Pure mapping from a model's JSON response to a `Playbook` (unit-tested without the network).
    public static func playbook(from raw: String, offerSentence: String, contextNotes: String) throws -> Playbook {
        let generated = try JSONExtraction.decodeFirst(PlaybookPrompts.Generated.self, from: raw)
        let openers = generated.openers.map { Opener(signal: $0.signal, text: $0.text) }
        let questions = generated.discoveryQuestions.map { DiscoveryQuestion(text: $0) }
        let objections = generated.objectionCards.map { ObjectionCard(trigger: $0.trigger, response: $0.response) }
        guard !openers.isEmpty || !objections.isEmpty else {
            throw LLMError.decoding("Generated playbook had no openers or objection cards")
        }
        return Playbook(
            offerSentence: offerSentence,
            contextNotes: contextNotes,
            openers: openers,
            discoveryQuestions: questions,
            objectionCards: objections
        )
    }

    // MARK: - The self-improving loop

    /// Return a new playbook with weights nudged by a logged call outcome.
    ///
    /// Multiplicative updates keep this deterministic and order-independent:
    /// a win bumps the used opener and resolved objections by `(1 + rate)`; a loss
    /// decays the used opener and failed objections by `(1 - rate)`. Weights are
    /// clamped to `[minWeight, maxWeight]`.
    public func applyOutcome(_ signal: OutcomeSignal, to playbook: Playbook, learningRate: Double = 0.2) -> Playbook {
        var result = playbook
        let up = 1.0 + learningRate
        let down = 1.0 - learningRate

        if let openerID = signal.usedOpenerID {
            adjust(&result.openers, id: openerID, factor: signal.outcome.isPositive ? up : down)
        }
        for id in signal.resolvedObjectionIDs {
            adjustObjection(&result.objectionCards, id: id, factor: up)
        }
        for id in signal.failedObjectionIDs {
            adjustObjection(&result.objectionCards, id: id, factor: down)
        }
        result.updatedAt = Date()
        return result
    }

    private func adjust(_ openers: inout [Opener], id: UUID, factor: Double) {
        guard let idx = openers.firstIndex(where: { $0.id == id }) else { return }
        openers[idx].weight = clamp(openers[idx].weight * factor)
    }

    private func adjustObjection(_ cards: inout [ObjectionCard], id: UUID, factor: Double) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[idx].weight = clamp(cards[idx].weight * factor)
    }

    private func clamp(_ value: Double) -> Double {
        min(Self.maxWeight, max(Self.minWeight, value))
    }

    /// Openers ordered by weight (best first) — used to surface the strongest opener in the cockpit.
    public func rankedOpeners(_ playbook: Playbook) -> [Opener] {
        playbook.openers.sorted { $0.weight > $1.weight }
    }
}
