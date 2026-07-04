import Foundation

/// A signal-based opening line (Deals Machine's "openers tied to a real signal").
public struct Opener: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    /// The buying/context signal this opener is tuned for (e.g. "recently hired sales reps").
    public var signal: String
    public var text: String
    /// Relative weight; nudged up/down by call outcomes.
    public var weight: Double

    public init(id: UUID = UUID(), signal: String, text: String, weight: Double = 1.0) {
        self.id = id
        self.signal = signal
        self.text = text
        self.weight = weight
    }
}

/// A discovery question to move the conversation forward.
public struct DiscoveryQuestion: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

/// An objection and the recommended response.
public struct ObjectionCard: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    /// The objection as the prospect might phrase it (e.g. "we already have a vendor").
    public var trigger: String
    public var response: String
    /// Relative weight; nudged up when the objection is resolved, down when it loses the call.
    public var weight: Double

    public init(id: UUID = UUID(), trigger: String, response: String, weight: Double = 1.0) {
        self.id = id
        self.trigger = trigger
        self.response = response
        self.weight = weight
    }
}

/// The "brain" the live cockpit coaches from: one offer/vertical, its openers,
/// discovery questions, and objection responses. Self-improving via `PlaybookService.applyOutcome`.
public struct Playbook: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    /// One-sentence description of what you sell and to whom.
    public var offerSentence: String
    /// Optional extra context pasted by the rep (product notes, pricing, differentiators).
    public var contextNotes: String
    public var openers: [Opener]
    public var discoveryQuestions: [DiscoveryQuestion]
    public var objectionCards: [ObjectionCard]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        offerSentence: String,
        contextNotes: String = "",
        openers: [Opener] = [],
        discoveryQuestions: [DiscoveryQuestion] = [],
        objectionCards: [ObjectionCard] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.offerSentence = offerSentence
        self.contextNotes = contextNotes
        self.openers = openers
        self.discoveryQuestions = discoveryQuestions
        self.objectionCards = objectionCards
        self.updatedAt = updatedAt
    }

    /// A short, display name derived from the offer sentence.
    public var title: String {
        let trimmed = offerSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled playbook" }
        return String(trimmed.prefix(60))
    }
}
