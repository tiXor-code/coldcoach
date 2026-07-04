import SwiftUI
import ColdCoachCore

struct CallView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var permissions: PermissionsManager

    @State private var selectedPlaybookID: UUID?
    @State private var audioMode: AudioMode = .speakerphoneMic
    @StateObject private var overlayModel = OverlayModel()
    @State private var overlayController: OverlayController?
    @StateObject private var holder = CallSessionHolder()
    @State private var endedRecord: CallRecord?
    @State private var outcome: CallOutcome = .booked
    @State private var usedOpenerID: UUID?

    private var playbook: Playbook? {
        model.playbooks.first { $0.id == selectedPlaybookID } ?? model.playbooks.first
    }

    var body: some View {
        Group {
            if let record = endedRecord {
                outcomeForm(for: record)
            } else if let live = holder.current {
                ActiveCallView(session: live, onEnd: { await stop() })
            } else {
                setupView
            }
        }
        .navigationTitle("New Call")
        .onAppear {
            audioMode = model.settings.defaultAudioMode
            if selectedPlaybookID == nil { selectedPlaybookID = model.playbooks.first?.id }
        }
    }

    // MARK: - Setup / idle

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Picker("Playbook", selection: $selectedPlaybookID) {
                    ForEach(model.playbooks) { Text($0.title).tag(Optional($0.id)) }
                }
                .frame(maxWidth: 280)

                Picker("Mode", selection: $audioMode) {
                    ForEach(AudioMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)

                Spacer()

                Button { Task { await start() } } label: {
                    Label("Start call", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(playbook == nil || model.makeProvider() == nil)
            }
            .padding()
            Divider()

            VStack(spacing: 14) {
                Image(systemName: "phone.badge.waveform").font(.system(size: 40)).foregroundStyle(.secondary)
                if model.playbooks.isEmpty {
                    Text("Create a playbook first (Playbooks tab).").foregroundStyle(.secondary)
                } else if model.makeProvider() == nil {
                    Text("Add an API key in Settings to start coaching.").foregroundStyle(.secondary)
                } else {
                    Text("Pick a playbook and mode, put your call on, then Start.").foregroundStyle(.secondary)
                    Text(audioMode == .speakerphoneMic
                         ? "Speakerphone mode: put the phone on speaker near your Mac."
                         : "System-audio mode: works alongside your softphone / Zoom (needs Screen Recording).")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Ended / outcome

    private func outcomeForm(for record: CallRecord) -> some View {
        Form {
            Section("How did it go?") {
                Picker("Outcome", selection: $outcome) {
                    ForEach(CallOutcome.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                if let pb = playbook, !pb.openers.isEmpty {
                    Picker("Opener you used (optional)", selection: $usedOpenerID) {
                        Text("— none —").tag(Optional<UUID>.none)
                        ForEach(pb.openers) { Text($0.text).tag(Optional($0.id)) }
                    }
                }
            }
            Section {
                Text("\(record.segments.count) transcript lines · \(record.coachingCards.count) coaching cards")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Discard") { endedRecord = nil }
                    Spacer()
                    Button("Save call") { saveOutcome(record) }.buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func start() async {
        guard let playbook, let provider = model.makeProvider() else { return }
        if audioMode == .systemPlusMic { _ = permissions.requestScreenRecording() }
        _ = await permissions.requestMicrophone()

        let controller = overlayController ?? OverlayController(model: overlayModel)
        overlayController = controller
        overlayModel.clear()
        controller.show(opacity: model.settings.overlayOpacity)

        let newSession = CallSession(
            playbook: playbook,
            audioMode: audioMode,
            provider: provider,
            coachingModel: model.settings.coachingModel,
            whisperModel: model.settings.whisperModel,
            onCard: { [weak overlayModel] card in overlayModel?.show(card) }
        )
        endedRecord = nil
        holder.current = newSession
        await newSession.start()
    }

    private func stop() async {
        guard let live = holder.current else { return }
        let record = await live.stop()
        overlayController?.hide()
        holder.current = nil
        outcome = .booked
        usedOpenerID = nil
        endedRecord = record
    }

    private func saveOutcome(_ record: CallRecord) {
        var finished = record
        finished.outcome = outcome
        model.saveCall(finished)
        if let pb = playbook {
            let updated = PlaybookService().applyOutcome(OutcomeSignal(outcome: outcome, usedOpenerID: usedOpenerID), to: pb)
            model.upsertPlaybook(updated)
        }
        endedRecord = nil
    }
}

/// Live call view that directly observes the CallSession so transcript/cards update.
struct ActiveCallView: View {
    @ObservedObject var session: CallSession
    var onEnd: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(session.isRunning ? "Live" : "Starting…", systemImage: "waveform")
                    .foregroundStyle(session.isRunning ? .red : .secondary)
                Text(session.audioMode.displayName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) { Task { await onEnd() } } label: {
                    Label("End call", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()

            HSplitView {
                transcriptColumn
                cardsColumn
            }
        }
    }

    private var transcriptColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(session.transcript) { seg in
                        HStack(alignment: .top, spacing: 8) {
                            Text(seg.role == .rep ? "You" : (seg.role == .prospect ? "Them" : "?"))
                                .font(.caption2.weight(.semibold))
                                .frame(width: 40, alignment: .leading)
                                .foregroundStyle(seg.role == .prospect ? .primary : .secondary)
                            Text(seg.text)
                        }
                        .id(seg.id)
                    }
                }
                .padding()
            }
            .onChange(of: session.transcript.count) { _, _ in
                if let last = session.transcript.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .frame(minWidth: 280)
    }

    private var cardsColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if session.cards.isEmpty {
                    Text("Coaching cards appear here (and float over your call).")
                        .font(.callout).foregroundStyle(.secondary).padding()
                }
                ForEach(session.cards.reversed()) { card in
                    CoachingCardRow(card: card, isLatest: card.id == session.cards.last?.id)
                }
                if let error = session.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.top)
                }
            }
            .padding()
        }
        .frame(minWidth: 300)
    }
}

@MainActor
final class CallSessionHolder: ObservableObject {
    @Published var current: CallSession?
}
