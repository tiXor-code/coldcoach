import Foundation

/// The category of moment a coaching card responds to.
public enum CoachingKind: String, Codable, Sendable {
    case objection
    case question
    case buyingSignal
    case opener
    case discovery
    case general

    public var label: String {
        switch self {
        case .objection: return "Objection"
        case .question: return "Question"
        case .buyingSignal: return "Buying signal"
        case .opener: return "Opener"
        case .discovery: return "Discovery"
        case .general: return "Coaching"
        }
    }
}

/// A single in-ear coaching card surfaced in the live cockpit overlay.
public struct CoachingCard: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var kind: CoachingKind
    /// One-line summary of the moment (e.g. "Price objection").
    public var headline: String
    /// The line the rep should actually say next.
    public var script: String
    /// Short "why this works" note.
    public var rationale: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: CoachingKind,
        headline: String,
        script: String,
        rationale: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.script = script
        self.rationale = rationale
        self.createdAt = createdAt
    }
}
