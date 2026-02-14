import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var commitHash = ProcessInfo.processInfo.environment["GIT_COMMIT_HASH"]
    @State private var saveStatus = ""

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
                Button("Save Sanitized Debug Log") { Task { await saveLog() } }
                if appState.diagnosticsStore.fullDiskAccessLikelyMissing {
                    Button("Open Full Disk Access Settings") { SystemSettingsLink.openFullDiskAccess() }
                }
                Spacer()
                #if DEBUG
                Toggle("Use Synthetic Test DB", isOn: $appState.dataStore.useSyntheticDB)
                    .onChange(of: appState.dataStore.useSyntheticDB) { _, _ in
                        Task { await appState.dataStore.resetAndLoad() }
                    }
                #endif
            }
            if !saveStatus.isEmpty {
                Text(saveStatus).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private func saveLog() async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "diagnostics-log.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try await appState.diagnosticsStore.saveSanitizedDebugLog(to: url, commitHash: commitHash)
            saveStatus = "Saved sanitized log."
        } catch {
            saveStatus = "Failed to save log: \(error.localizedDescription)"
        }
    }
}
