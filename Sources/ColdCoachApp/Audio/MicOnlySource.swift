import Foundation
import AVFoundation
import CoreAudio
import os
import ColdCoachCore

/// Mode A: captures the microphone with AVAudioEngine and emits ~2s windows of 16 kHz
/// mono audio. In speakerphone mode the mic hears both the rep and the prospect's
/// speakerphone audio; roles are resolved downstream by `RoleAssigner`.
///
/// The input device is selectable (nil = system default) so the user can point ColdCoach
/// at the mic that actually carries the call (e.g. a virtual/remote input) instead of
/// whatever happens to be the system default.
final class MicOnlySource: NSObject, AudioSource {
    let mode: AudioMode = .speakerphoneMic

    private static let log = Logger(subsystem: "net.coldcoach.app", category: "audio")

    private let engine = AVAudioEngine()
    private let deviceUID: String?
    private let windowSeconds: Double
    private var pending: [Float] = []
    private var elapsed: TimeInterval = 0
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    let chunks: AsyncStream<AudioChunk>

    init(deviceUID: String? = nil, windowSeconds: Double = 2.0) {
        self.deviceUID = deviceUID
        self.windowSeconds = windowSeconds
        var cont: AsyncStream<AudioChunk>.Continuation!
        self.chunks = AsyncStream { cont = $0 }
        super.init()
        self.continuation = cont
    }

    func start() async throws {
        let input = engine.inputNode

        // Bind to the chosen input device (must happen BEFORE reading the format / installing
        // the tap, or the engine caches the default device's format and mismatches on start).
        if let uid = deviceUID, let deviceID = AudioDevices.deviceID(forUID: uid), let au = input.audioUnit {
            var dev = deviceID
            let status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                                              kAudioUnitScope_Global, 0, &dev,
                                              UInt32(MemoryLayout<AudioDeviceID>.size))
            if status == noErr {
                Self.log.info("Capturing from input device UID \(uid, privacy: .public)")
            } else {
                Self.log.error("Failed to select input device \(uid, privacy: .public): OSStatus \(status)")
            }
        } else {
            Self.log.info("Capturing from the system default input device")
        }

        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        try engine.start()
        Self.log.info("Mic engine started (\(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) ch)")
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
