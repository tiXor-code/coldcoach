import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if model.needsOnboarding {
            OnboardingView()
        } else {
            MainView()
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case call = "New Call"
    case playbooks = "Playbooks"
    case history = "History"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .call: return "phone.badge.waveform"
        case .playbooks: return "book.closed"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct MainView: View {
    @State private var selection: SidebarItem? = .call

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationTitle("ColdCoach")
            .frame(minWidth: 190)
        } detail: {
            switch selection ?? .call {
            case .call: CallView()
            case .playbooks: PlaybookListView()
            case .history: HistoryView()
            }
        }
    }
}
