import SwiftUI

@main
struct MessageExporterMainApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}
