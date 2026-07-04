import Foundation

/// A completed (or in-progress) call: which playbook, how it was captured, the transcript,
/// the coaching cards shown, and the logged outcome.
public struct CallRecord: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var playbookID: UUID?
    public var audioMode: AudioMode
    public var startedAt: Date
    public var endedAt: Date?
    public var outcome: CallOutcome?
    public var segments: [TranscriptSegment]
    public var coachingCards: [CoachingCard]

    public init(
        id: UUID = UUID(),
        playbookID: UUID? = nil,
        audioMode: AudioMode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        outcome: CallOutcome? = nil,
        segments: [TranscriptSegment] = [],
        coachingCards: [CoachingCard] = []
    ) {
        self.id = id
        self.playbookID = playbookID
        self.audioMode = audioMode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcome = outcome
        self.segments = segments
        self.coachingCards = coachingCards
    }
}
