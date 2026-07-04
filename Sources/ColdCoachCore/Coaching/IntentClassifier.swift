import Foundation

/// What a prospect utterance signals, used to decide whether (and how) to coach.
public enum Intent: String, Sendable, Equatable {
    case objection
    case question
    case buyingSignal
    case smalltalk
    case none
}

/// Fast, dependency-free rule-based classifier for prospect turns.
///
/// It is intentionally cheap and runs on every finalized segment; the LLM is only
/// invoked once the engine decides a card is warranted. Order matters: objections
/// are checked before buying signals so brush-offs like "send me an email" are not
/// mistaken for interest.
public struct IntentClassifier: Sendable {
    public init() {}

    static let objectionMarkers: [String] = [
        "not interested", "no interest", "too expensive", "too much money", "no budget",
        "can't afford", "cannot afford", "already have", "already using", "already working with",
        "happy with", "send me an email", "send an email", "email me", "call me later",
        "call me back", "call back later", "not a good time", "bad time", "who is this",
        "how did you get my", "take me off", "remove me", "not the right person",
        "wrong person", "think about it", "not right now", "maybe later", "we're all set",
        "we are all set", "no thanks", "no thank you", "don't have time", "in a meeting"
    ]

    static let buyingSignalMarkers: [String] = [
        "how much", "what's the price", "what is the price", "what does it cost", "how much does it cost",
        "pricing", "send me a proposal", "sign up", "get started", "next step", "next steps",
        "book a", "schedule a", "set up a", "demo", "free trial", "start a trial",
        "tell me more", "sounds interesting", "sounds good", "interested in", "when can we start",
        "how does it work"
    ]

    static let questionLeads: [String] = [
        "what", "how", "why", "when", "where", "who", "which", "can you", "could you",
        "do you", "are you", "is this", "is that", "would you"
    ]

    public func classify(_ text: String) -> Intent {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return .none }

        if Self.objectionMarkers.contains(where: { t.contains($0) }) { return .objection }
        if Self.buyingSignalMarkers.contains(where: { t.contains($0) }) { return .buyingSignal }
        if isQuestion(t) { return .question }
        return .smalltalk
    }

    private func isQuestion(_ t: String) -> Bool {
        if t.contains("?") { return true }
        let firstWords = t.split(separator: " ").prefix(2).joined(separator: " ")
        return Self.questionLeads.contains { firstWords.hasPrefix($0) }
    }

    /// Whether this intent should ever surface a coaching card.
    public static func warrantsCard(_ intent: Intent) -> Bool {
        switch intent {
        case .objection, .question, .buyingSignal: return true
        case .smalltalk, .none: return false
        }
    }

    public static func kind(for intent: Intent) -> CoachingKind {
        switch intent {
        case .objection: return .objection
        case .question: return .question
        case .buyingSignal: return .buyingSignal
        case .smalltalk, .none: return .general
        }
    }
}
