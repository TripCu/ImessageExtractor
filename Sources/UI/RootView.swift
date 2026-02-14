import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasValidBundleIdentifier {
                LaunchGuardView()
            } else if appState.setupCompleted {
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

struct LaunchGuardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launch From .app Bundle Required")
                .font(.title2)
                .bold()

            Text("This build was started without a bundle identifier. Permissions and Contacts integration require launching the generated .app bundle.")
                .foregroundStyle(.secondary)

            Text("Run:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("./scripts/create-app-bundle.sh release\nopen .build/release/MessageExporterApp.app")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack {
                Button("Open Project Folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
                }
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
