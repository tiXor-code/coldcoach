import SwiftUI
import ColdCoachCore

/// The stacked coaching cards rendered inside the floating overlay panel.
struct CoachingOverlayView: View {
    @ObservedObject var model: OverlayModel
    var opacity: Double = 0.95

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.cards.isEmpty {
                Text("ColdCoach — listening…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                ForEach(model.cards) { card in
                    CoachingCardRow(card: card, isLatest: card.id == model.cards.last?.id)
                }
            }
        }
        .padding(10)
        .frame(width: 340, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        .opacity(opacity)
        .shadow(radius: 18, y: 6)
    }
}

struct CoachingCardRow: View {
    let card: CoachingCard
    var isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(card.headline.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(card.kind.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(card.script)
                .font(isLatest ? .headline : .subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if !card.rationale.isEmpty {
                Text(card.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isLatest ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var accent: Color {
        switch card.kind {
        case .objection: return .orange
        case .buyingSignal: return .green
        case .question: return .blue
        default: return .gray
        }
    }
}
