import Foundation

/// Turns audio into transcript segments. Implemented in the app layer by a
/// WhisperKit-backed service; mocked in Core for tests.
public protocol TranscriptionService: AnyObject {
    /// Transcribe one audio chunk into zero or more segments (may include partials).
    func transcribe(_ chunk: AudioChunk) async throws -> [TranscriptSegment]
    /// Clear any streaming state between calls.
    func reset() async
}

/// Optional diarization for single-mic Mode A: assigns roles to segments.
/// Implemented in the app by a SpeakerKit-backed service.
public protocol DiarizationService: AnyObject {
    /// Given a window of segments (and optionally the audio), return them with roles assigned.
    func assignRoles(to segments: [TranscriptSegment]) async -> [TranscriptSegment]
}

/// A trivial diarizer that leaves roles as-is (used when diarization is disabled).
public final class PassthroughDiarization: DiarizationService {
    public init() {}
    public func assignRoles(to segments: [TranscriptSegment]) async -> [TranscriptSegment] { segments }
}
