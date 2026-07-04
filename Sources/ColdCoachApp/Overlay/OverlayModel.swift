import Foundation
import SwiftUI
import ColdCoachCore

/// Backing state for the floating cockpit overlay: the most recent coaching cards.
@MainActor
final class OverlayModel: ObservableObject {
    @Published private(set) var cards: [CoachingCard] = []
    private let maxVisible: Int

    init(maxVisible: Int = 3) { self.maxVisible = maxVisible }

    func show(_ card: CoachingCard) {
        cards.append(card)
        if cards.count > maxVisible {
            cards.removeFirst(cards.count - maxVisible)
        }
    }

    func clear() { cards.removeAll() }
}
