import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.setupCompleted {
                MainShellView()
            } else {
                SetupWizardView()
            }
        }
        .sheet(isPresented: $appState.showDiagnostics) {
            DiagnosticsView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}
