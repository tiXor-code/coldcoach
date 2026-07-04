import SwiftUI
import AppKit
import ColdCoachCore

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.needsOnboarding {
                OnboardingView()
            } else {
                MainView()
            }
        }
        // Check for a newer release on launch (respects the auto-update toggle + daily throttle).
        .task { await model.checkForUpdates() }
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
    @EnvironmentObject var model: AppModel
    @State private var selection: SidebarItem? = .call

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationTitle("ColdCoach")
            .frame(minWidth: 190)
        } detail: {
            VStack(spacing: 0) {
                if let update = model.availableUpdate {
                    UpdateBanner(update: update)
                }
                switch selection ?? .call {
                case .call: CallView()
                case .playbooks: PlaybookListView()
                case .history: HistoryView()
                }
            }
        }
    }
}

/// Non-modal "update available" banner. Never downloads or replaces the app itself;
/// it points to the right install path (brew upgrade, or the release page).
struct UpdateBanner: View {
    @EnvironmentObject var model: AppModel
    let update: UpdateInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("ColdCoach \(update.version.description) is available").font(.subheadline).bold()
                Text(update.explanation).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            action
            Button {
                model.availableUpdate = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(10)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding([.horizontal, .top], 12)
    }

    @ViewBuilder private var action: some View {
        switch update.channel {
        case .brew:
            Button("Copy update command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(UpdateInfo.brewCommand, forType: .string)
            }
        case .dmg, .source:
            Button("Open release") {
                if let url = URL(string: update.dmgURL ?? update.releaseURL) { NSWorkspace.shared.open(url) }
            }
        }
    }
}
