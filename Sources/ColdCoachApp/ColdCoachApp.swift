import SwiftUI

@main
struct ColdCoachApp: App {
    @StateObject private var model = AppModel.live()
    @StateObject private var permissions = PermissionsManager()

    var body: some Scene {
        WindowGroup("ColdCoach") {
            RootView()
                .environmentObject(model)
                .environmentObject(permissions)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Task { await model.checkForUpdates(force: true) } }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(permissions)
                .frame(width: 520)
        }
    }
}
