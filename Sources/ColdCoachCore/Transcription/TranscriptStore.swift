import Foundation

/// Rolling conversation buffer. Partial segments are upserted by id as WhisperKit
/// refines them; finalized segments feed the CoachingEngine and, at call end, the CallRecord.
public final class TranscriptStore {
    public private(set) var segments: [TranscriptSegment] = []
    private let maxSegments: Int

    public init(maxSegments: Int = 500) {
        self.maxSegments = maxSegments
    }

    /// Insert a new segment, or replace an existing one with the same id (partial -> final).
    /// Returns true if the segment is finalized and newly settled (useful for triggering coaching).
    @discardableResult
    public func upsert(_ segment: TranscriptSegment) -> Bool {
        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
            let wasFinal = segments[idx].isFinal
            segments[idx] = segment
            trim()
            return segment.isFinal && !wasFinal
        } else {
            segments.append(segment)
            trim()
            return segment.isFinal
        }
    }

    private func trim() {
        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }
    }

    /// The most recent `n` segments in order.
    public func recent(_ n: Int) -> [TranscriptSegment] {
        Array(segments.suffix(n))
    }

    public var finalized: [TranscriptSegment] {
        segments.filter { $0.isFinal }
    }

    public func clear() {
        segments.removeAll(keepingCapacity: true)
    }
}
