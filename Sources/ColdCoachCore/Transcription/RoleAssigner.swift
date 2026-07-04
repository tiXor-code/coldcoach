import Foundation

/// Assigns rep/prospect roles to single-mic (Mode A) transcript segments using a
/// pause-gap heuristic: the rep speaks first on an outbound call, and the speaker is
/// assumed to switch whenever there is a silence gap between consecutive segments.
///
/// This makes Mode A coaching work with zero extra dependencies. It is deliberately
/// simple; SpeakerKit diarization (or LLM role inference) can replace it for accuracy.
public struct RoleAssigner: Sendable {
    public var gapThreshold: TimeInterval
    public var firstSpeaker: Role

    public init(gapThreshold: TimeInterval = 0.8, firstSpeaker: Role = .rep) {
        self.gapThreshold = gapThreshold
        self.firstSpeaker = firstSpeaker
    }

    /// Assign roles across an ordered batch of segments (in place ordering preserved).
    public func assign(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        guard !segments.isEmpty else { return segments }
        var result = segments
        var current = firstSpeaker
        for i in result.indices {
            if i > 0 {
                let gap = result[i].start - result[i - 1].end
                if gap >= gapThreshold { current = toggle(current) }
            }
            result[i].role = current
        }
        return result
    }

    /// Assign a role to the next segment given the previously assigned one (streaming use).
    public func nextRole(previous: TranscriptSegment?, current segment: TranscriptSegment) -> Role {
        guard let previous else { return firstSpeaker }
        let gap = segment.start - previous.end
        return gap >= gapThreshold ? toggle(previous.role) : previous.role
    }

    private func toggle(_ role: Role) -> Role {
        switch role {
        case .rep: return .prospect
        case .prospect: return .rep
        case .unknown: return firstSpeaker
        }
    }
}
