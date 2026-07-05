import Foundation
import WhisperKit
import os
import ColdCoachCore

/// WhisperKit-backed transcription. Each audio window is transcribed on-device; the model
/// is downloaded on first use. Roles are carried through from the audio source (Mode B) or
/// left `.unknown` (Mode A) for the RoleAssigner to fill in.
///
/// Note: WhisperKit's exact `transcribe` signature can vary between releases. This uses the
/// window-batch API (`transcribe(audioArray:)`); swap to `AudioStreamTranscriber` for tighter
/// latency once validated on-device.
final class WhisperKitTranscription: TranscriptionService {
    private static let log = Logger(subsystem: "net.coldcoach.app", category: "transcription")

    private var whisper: WhisperKit?
    private let modelName: String

    init(modelName: String) { self.modelName = modelName }

    /// Load (and, on first run, download) the model up front so the call UI can show a
    /// "loading model" state instead of a silent, empty "Live" call.
    func preload() async throws {
        _ = try await ensureLoaded()
    }

    private func ensureLoaded() async throws -> WhisperKit {
        if let whisper { return whisper }
        Self.log.info("Loading WhisperKit model \(self.modelName, privacy: .public)…")
        let loaded = try await WhisperKit(model: modelName)
        whisper = loaded
        Self.log.info("WhisperKit model \(self.modelName, privacy: .public) ready")
        return loaded
    }

    // Qualify AudioChunk: WhisperKit also exports a type named AudioChunk.
    func transcribe(_ chunk: ColdCoachCore.AudioChunk) async throws -> [TranscriptSegment] {
        let whisper = try await ensureLoaded()
        let results = try await whisper.transcribe(audioArray: chunk.samples)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isMeaningful(text) else { return [] }

        let windowLength = Double(chunk.samples.count) / chunk.sampleRate
        let segment = TranscriptSegment(
            role: chunk.role ?? .unknown,
            text: text,
            start: chunk.timestamp,
            end: chunk.timestamp + windowLength,
            isFinal: true
        )
        return [segment]
    }

    func reset() async {
        // Window-batch transcription keeps no cross-window state.
    }

    /// Filter WhisperKit's silence artifacts (e.g. "[BLANK_AUDIO]") and empty output.
    private func isMeaningful(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.isEmpty { return false }
        if lower.contains("blank_audio") || lower.contains("[silence]") { return false }
        let letters = text.filter { $0.isLetter }
        return letters.count >= 2
    }
}
