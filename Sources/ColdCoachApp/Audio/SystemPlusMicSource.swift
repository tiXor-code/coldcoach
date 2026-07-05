import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreAudio
import os
import ColdCoachCore

/// Mode B: captures the prospect's audio via ScreenCaptureKit system audio and the rep's
/// audio via the microphone, emitting role-tagged 16 kHz mono windows. Works alongside any
/// softphone, Zoom, or phone-mirroring app.
///
/// The mic-side input device is selectable (nil = system default), mirroring `MicOnlySource`,
/// so the picker in the call setup UI has the same effect in both audio modes.
///
/// Requires Screen Recording permission (for system audio) and Microphone permission.
final class SystemPlusMicSource: NSObject, AudioSource, SCStreamOutput, SCStreamDelegate {
    let mode: AudioMode = .systemPlusMic

    private static let log = Logger(subsystem: "net.coldcoach.app", category: "audio")
    private let windowSeconds: Double
    private let deviceUID: String?
    private let micEngine = AVAudioEngine()
    private var stream: SCStream?

    private var systemPending: [Float] = []
    private var micPending: [Float] = []
    private var systemElapsed: TimeInterval = 0
    private var micElapsed: TimeInterval = 0
    private let queue = DispatchQueue(label: "net.coldcoach.systemaudio")

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
        // System audio via ScreenCaptureKit (audio-only: we register only an audio output).
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "ColdCoach", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display available for system audio capture."])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = Int(AudioConversion.targetSampleRate)
        config.channelCount = 1
        // Minimal video (SCStream requires a video config even for audio capture).
        config.width = 2
        config.height = 2

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream

        // Microphone via AVAudioEngine, bound to the chosen input device (must happen BEFORE
        // reading the format / installing the tap — see MicOnlySource.start()).
        let input = micEngine.inputNode
        if let uid = deviceUID, let deviceID = AudioDevices.deviceID(forUID: uid), let au = input.audioUnit {
            var dev = deviceID
            let status = AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                                              kAudioUnitScope_Global, 0, &dev,
                                              UInt32(MemoryLayout<AudioDeviceID>.size))
            if status == noErr {
                Self.log.info("Capturing mic from input device UID \(uid, privacy: .public)")
            } else {
                Self.log.error("Failed to select input device \(uid, privacy: .public): OSStatus \(status)")
            }
        } else {
            Self.log.info("Capturing mic from the system default input device")
        }

        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handleMic(buffer)
        }
        micEngine.prepare()
        try micEngine.start()
    }

    func stop() async {
        micEngine.inputNode.removeTap(onBus: 0)
        micEngine.stop()
        if let stream { try? await stream.stopCapture() }
        stream = nil
        continuation?.finish()
    }

    // MARK: - SCStreamDelegate

    /// If the system-audio stream stops mid-call (permission revoked, display change), it used
    /// to be swallowed. Log it and end the audio stream so the call does not sit there dead.
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Self.log.error("System-audio stream stopped: \(error.localizedDescription, privacy: .public)")
        continuation?.finish()
    }

    // MARK: - System audio (prospect)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              let pcm = AudioConversion.pcmBuffer(from: sampleBuffer),
              let samples = AudioConversion.monoFloat16k(from: pcm) else { return }
        queue.async { [weak self] in
            self?.accumulate(samples, into: &self!.systemPending, elapsed: &self!.systemElapsed, role: .prospect)
        }
    }

    // MARK: - Microphone (rep)

    private func handleMic(_ buffer: AVAudioPCMBuffer) {
        guard let samples = AudioConversion.monoFloat16k(from: buffer) else { return }
        queue.async { [weak self] in
            self?.accumulate(samples, into: &self!.micPending, elapsed: &self!.micElapsed, role: .rep)
        }
    }

    private func accumulate(_ samples: [Float], into pending: inout [Float], elapsed: inout TimeInterval, role: Role) {
        pending.append(contentsOf: samples)
        let windowSampleCount = Int(AudioConversion.targetSampleRate * windowSeconds)
        while pending.count >= windowSampleCount {
            let window = Array(pending.prefix(windowSampleCount))
            pending.removeFirst(windowSampleCount)
            let chunk = AudioChunk(samples: window, sampleRate: AudioConversion.targetSampleRate, timestamp: elapsed, role: role)
            elapsed += Double(window.count) / AudioConversion.targetSampleRate
            continuation?.yield(chunk)
        }
    }
}
