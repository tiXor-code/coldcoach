import Foundation
import SwiftUI
import os
import ColdCoachCore

/// The observable phase of a live call, so the UI is never a silent black box.
enum CallStatus: Equatable {
    case idle
    case loadingModel        // downloading/loading the on-device speech model
    case startingAudio       // opening the input device
    case listening           // capturing + transcribing
    case noAudioDetected     // running, but the mic has been silent for a while
    case error(String)

    /// True once capture is actually up (drives the "Live" indicator).
    var isLive: Bool {
        switch self {
        case .listening, .noAudioDetected: return true
        default: return false
        }
    }
}

/// Orchestrates one live call: capture -> transcribe -> assign roles -> coach -> overlay,
/// and assembles the CallRecord to persist afterward.
@MainActor
final class CallSession: ObservableObject {
    @Published private(set) var status: CallStatus = .idle
    @Published private(set) var isRunning = false
    @Published private(set) var transcript: [TranscriptSegment] = []
    @Published private(set) var cards: [CoachingCard] = []
    /// 0...1 input meter (per ~2s window) so the user can see the mic is hearing audio.
    @Published private(set) var inputLevel: Float = 0
    @Published var errorMessage: String?

    let playbook: Playbook
    let audioMode: AudioMode

    private static let log = Logger(subsystem: "net.coldcoach.app", category: "call")

    private let provider: LLMProvider
    private let coachingModel: String
    private let whisperModel: String
    private let inputDeviceUID: String?
    private let onCard: (CoachingCard) -> Void

    private let store = TranscriptStore()
    private let engine: CoachingEngine
    private let roleAssigner = RoleAssigner()

    private var source: AudioSource?
    private var transcriber: WhisperKitTranscription?
    private var pipeline: Task<Void, Never>?
    private var lastAssigned: TranscriptSegment?
    private var startedAt = Date()
    private var sawAudio = false
    private let recordID = UUID()

    /// After this many seconds of only-silence windows, warn that no audio is being heard.
    private let noAudioGrace: TimeInterval = 6

    init(
        playbook: Playbook,
        audioMode: AudioMode,
        provider: LLMProvider,
        coachingModel: String,
        whisperModel: String,
        inputDeviceUID: String?,
        onCard: @escaping (CoachingCard) -> Void
    ) {
        self.playbook = playbook
        self.audioMode = audioMode
        self.provider = provider
        self.coachingModel = coachingModel
        self.whisperModel = whisperModel
        self.inputDeviceUID = inputDeviceUID
        self.onCard = onCard
        // Mode B has reliable per-stream roles, so gate coaching on the prospect turn.
        // Mode A is a mixed mono mic (no reliable diarization), so coach on content.
        self.engine = CoachingEngine(config: .init(requireProspectRole: audioMode == .systemPlusMic))
    }

    func start() async {
        guard !isRunning else { return }
        engine.reset()
        store.clear()
        transcript = []
        cards = []
        lastAssigned = nil
        sawAudio = false
        inputLevel = 0
        startedAt = Date()
        errorMessage = nil

        let transcriber = WhisperKitTranscription(modelName: whisperModel)
        self.transcriber = transcriber

        // 1. Load the speech model first (visible state), so a slow first-run download
        //    does not masquerade as a "Live" call with an empty transcript.
        status = .loadingModel
        do {
            try await transcriber.preload()
        } catch {
            fail("Could not load the speech model: \(error.localizedDescription)")
            return
        }

        // 2. Open the chosen input device.
        status = .startingAudio
        let source: AudioSource = audioMode == .systemPlusMic
            ? SystemPlusMicSource(deviceUID: inputDeviceUID)
            : MicOnlySource(deviceUID: inputDeviceUID)
        self.source = source
        do {
            try await source.start()
        } catch {
            fail("Could not start audio capture: \(error.localizedDescription)")
            return
        }

        // 3. Consume audio.
        status = .listening
        isRunning = true
        Self.log.info("Call started (mode \(self.audioMode.rawValue, privacy: .public))")
        pipeline = Task { [weak self] in
            guard let self else { return }
            for await chunk in source.chunks {
                if Task.isCancelled { break }
                await self.process(chunk, using: transcriber)
            }
        }
    }

    private func fail(_ message: String) {
        Self.log.error("\(message, privacy: .public)")
        errorMessage = message
        status = .error(message)
    }

    private func process(_ chunk: AudioChunk, using transcriber: WhisperKitTranscription) async {
        // Update the input meter + no-audio detection from the raw window, independent of
        // whether it transcribes to anything (a silent/wrong device shows a flat meter).
        let rms = AudioLevel.rms(chunk.samples)
        inputLevel = AudioLevel.meter(rms: rms)
        if AudioLevel.isSilent(rms: rms) {
            if !sawAudio, chunk.timestamp >= noAudioGrace, status == .listening {
                status = .noAudioDetected
                Self.log.error("No audio detected after \(self.noAudioGrace, privacy: .public)s — check the input device")
            }
        } else {
            sawAudio = true
            if status == .noAudioDetected { status = .listening }
        }

        let segments: [TranscriptSegment]
        do {
            segments = try await transcriber.transcribe(chunk)
        } catch {
            fail("Transcription error: \(error.localizedDescription)")
            return
        }

        for var segment in segments {
            // Mode A: fill in the role via the pause-gap heuristic (labels the transcript;
            // it does NOT gate coaching in Mode A — see CoachingEngine.Config).
            if segment.role == .unknown {
                segment.role = roleAssigner.nextRole(previous: lastAssigned, current: segment)
            }
            lastAssigned = segment
            store.upsert(segment)
            transcript = store.segments

            do {
                if let card = try await engine.coach(
                    segment: segment,
                    playbook: playbook,
                    offerSentence: playbook.offerSentence,
                    recentTurns: store.recent(6),
                    coachingModel: coachingModel,
                    provider: provider
                ) {
                    cards.append(card)
                    onCard(card)
                }
            } catch {
                errorMessage = "Coaching error: \(error.localizedDescription)"
                Self.log.error("Coaching error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Stop the call and return the record to persist (outcome is set by the caller afterward).
    func stop() async -> CallRecord {
        pipeline?.cancel()
        pipeline = nil
        await source?.stop()
        source = nil
        isRunning = false
        status = .idle
        inputLevel = 0

        return CallRecord(
            id: recordID,
            playbookID: playbook.id,
            audioMode: audioMode,
            startedAt: startedAt,
            endedAt: Date(),
            outcome: nil,
            segments: store.finalized,
            coachingCards: cards
        )
    }
}
