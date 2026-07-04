import Foundation

/// A window of mono PCM audio delivered by an `AudioSource`.
public struct AudioChunk: Sendable {
    public var samples: [Float]
    public var sampleRate: Double
    /// Seconds from the start of the call.
    public var timestamp: TimeInterval
    /// Known when the source can attribute a stream to a side (Mode B: mic = rep, system = prospect).
    /// `nil` in single-mic Mode A, where role comes from diarization or the LLM.
    public var role: Role?

    public init(samples: [Float], sampleRate: Double, timestamp: TimeInterval, role: Role? = nil) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.timestamp = timestamp
        self.role = role
    }
}

/// Captures the call audio. Implemented in the app layer:
///   - `MicOnlySource` (AVAudioEngine) for Mode A speakerphone.
///   - `SystemPlusMicSource` (ScreenCaptureKit + AVAudioEngine) for Mode B.
public protocol AudioSource: AnyObject {
    var mode: AudioMode { get }
    /// Stream of captured audio windows. Consume this to feed the transcription pipeline.
    var chunks: AsyncStream<AudioChunk> { get }
    func start() async throws
    func stop() async
}
