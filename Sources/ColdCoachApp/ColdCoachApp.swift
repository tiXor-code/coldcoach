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

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(permissions)
                .frame(width: 520)
        }
    }
}
