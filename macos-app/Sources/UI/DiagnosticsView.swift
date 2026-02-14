import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var commitHash = ProcessInfo.processInfo.environment["GIT_COMMIT_HASH"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnostics").font(.title3).bold()
            Text(appState.diagnosticsStore.report(commitHash: commitHash))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Copy Diagnostic Report") {
                    appState.diagnosticsStore.copyReport(commitHash: commitHash)
                }
                Button("Save Sanitized Debug Log") { saveLog() }
                Spacer()
                #if DEBUG
                Toggle("Use Synthetic Test DB", isOn: $appState.dataStore.useSyntheticDB)
                    .onChange(of: appState.dataStore.useSyntheticDB) { _, _ in
                        Task { await appState.dataStore.resetAndLoad() }
                    }
                #endif
            }
        }
        .padding(20)
    }

    private func saveLog() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "diagnostics-log.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let report = appState.diagnosticsStore.report(commitHash: commitHash)
        try? report.data(using: .utf8)?.write(to: url, options: .withoutOverwriting)
    }
}
