import Foundation

/// One utterance (or partial) in the rolling conversation transcript.
///
/// `start`/`end` are seconds from the start of the call. The CoachingEngine uses
/// `end` as a deterministic clock for debouncing, so tests never depend on wall time.
public struct TranscriptSegment: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var role: Role
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval
    public var confidence: Double?
    /// `false` while WhisperKit is still refining this segment (partial), `true` once finalized.
    public var isFinal: Bool

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil,
        isFinal: Bool = true
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.isFinal = isFinal
    }

    /// Normalized, lowercased text for keyword matching.
    public var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
