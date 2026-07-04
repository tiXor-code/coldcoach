import SwiftUI
import ColdCoachCore

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: CallRecord?

    var body: some View {
        Group {
            if model.calls.isEmpty {
                ContentUnavailableView("No calls yet", systemImage: "clock.arrow.circlepath",
                    description: Text("Your call history and coaching cards will appear here."))
            } else {
                List {
                    ForEach(model.calls) { call in
                        Button { selected = call } label: { row(call) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { $0.map { model.calls[$0].id }.forEach(model.deleteCall) }
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $selected) { CallDetailView(record: $0) }
    }

    private func row(_ call: CallRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(call.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                Text("\(call.audioMode.displayName) · \(call.coachingCards.count) cards")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let outcome = call.outcome {
                Text(outcome.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(outcome.isPositive ? Color.green.opacity(0.18) : Color.secondary.opacity(0.15),
                                in: Capsule())
            }
        }
    }
}

struct CallDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: CallRecord

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(record.startedAt.formatted(date: .long, time: .shortened)).font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()
            Divider()
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transcript").font(.headline)
                        ForEach(record.segments) { seg in
                            HStack(alignment: .top, spacing: 8) {
                                Text(seg.role == .rep ? "You" : (seg.role == .prospect ? "Them" : "?"))
                                    .font(.caption2.weight(.semibold)).frame(width: 40, alignment: .leading)
                                Text(seg.text)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Coaching cards").font(.headline)
                        ForEach(record.coachingCards) { CoachingCardRow(card: $0, isLatest: false) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
        .frame(width: 720, height: 520)
    }
}
