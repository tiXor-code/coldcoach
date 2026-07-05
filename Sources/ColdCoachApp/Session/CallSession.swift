import Foundation
import SwiftUI
import ColdCoachCore

/// Orchestrates one live call: capture -> transcribe -> assign roles -> coach -> overlay,
/// and assembles the CallRecord to persist afterward.
@MainActor
final class CallSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var transcript: [TranscriptSegment] = []
    @Published private(set) var cards: [CoachingCard] = []
    @Published var errorMessage: String?

    let playbook: Playbook
    let audioMode: AudioMode

    private let provider: LLMProvider
    private let coachingModel: String
    private let whisperModel: String
    private let onCard: (CoachingCard) -> Void

    private let store = TranscriptStore()
    private let engine: CoachingEngine
    private let roleAssigner = RoleAssigner()

    private var source: AudioSource?
    private var transcriber: TranscriptionService?
    private var pipeline: Task<Void, Never>?
    private var lastAssigned: TranscriptSegment?
    private var startedAt = Date()
    private let recordID = UUID()

    init(
        playbook: Playbook,
        audioMode: AudioMode,
        provider: LLMProvider,
        coachingModel: String,
        whisperModel: String,
        onCard: @escaping (CoachingCard) -> Void
    ) {
        self.playbook = playbook
        self.audioMode = audioMode
        self.provider = provider
        self.coachingModel = coachingModel
        self.whisperModel = whisperModel
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
        startedAt = Date()
        errorMessage = nil

        let source: AudioSource = audioMode == .systemPlusMic ? SystemPlusMicSource() : MicOnlySource()
        let transcriber = WhisperKitTranscription(modelName: whisperModel)
        self.source = source
        self.transcriber = transcriber

        do {
            try await source.start()
        } catch {
            errorMessage = "Could not start audio capture: \(error.localizedDescription)"
            return
        }

        isRunning = true
        pipeline = Task { [weak self] in
            guard let self else { return }
            for await chunk in source.chunks {
                if Task.isCancelled { break }
                await self.process(chunk, using: transcriber)
            }
        }
    }

    private func process(_ chunk: AudioChunk, using transcriber: TranscriptionService) async {
        let segments: [TranscriptSegment]
        do {
            segments = try await transcriber.transcribe(chunk)
        } catch {
            errorMessage = "Transcription error: \(error.localizedDescription)"
            return
        }

        for var segment in segments {
            // Mode A: fill in the role via the pause-gap heuristic.
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
