import Foundation
import AVFoundation
import ColdCoachCore

/// Mode A: captures the microphone with AVAudioEngine and emits ~2s windows of 16 kHz
/// mono audio. In speakerphone mode the mic hears both the rep and the prospect's
/// speakerphone audio; roles are resolved downstream by `RoleAssigner`.
final class MicOnlySource: NSObject, AudioSource {
    let mode: AudioMode = .speakerphoneMic

    private let engine = AVAudioEngine()
    private let windowSeconds: Double
    private var pending: [Float] = []
    private var elapsed: TimeInterval = 0
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    let chunks: AsyncStream<AudioChunk>

    init(windowSeconds: Double = 2.0) {
        self.windowSeconds = windowSeconds
        var cont: AsyncStream<AudioChunk>.Continuation!
        self.chunks = AsyncStream { cont = $0 }
        super.init()
        self.continuation = cont
    }

    func start() async throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() async {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        flush()
        continuation?.finish()
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        guard let samples = AudioConversion.monoFloat16k(from: buffer) else { return }
        pending.append(contentsOf: samples)
        let windowSampleCount = Int(AudioConversion.targetSampleRate * windowSeconds)
        while pending.count >= windowSampleCount {
            let window = Array(pending.prefix(windowSampleCount))
            pending.removeFirst(windowSampleCount)
            emit(window)
        }
    }

    private func flush() {
        if !pending.isEmpty {
            emit(pending)
            pending.removeAll()
        }
    }

    private func emit(_ samples: [Float]) {
        let chunk = AudioChunk(
            samples: samples,
            sampleRate: AudioConversion.targetSampleRate,
            timestamp: elapsed,
            role: nil // Mode A: role resolved by RoleAssigner downstream
        )
        elapsed += Double(samples.count) / AudioConversion.targetSampleRate
        continuation?.yield(chunk)
    }
}
