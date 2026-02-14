import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject var appState: AppState
    @State private var dbStatus: CheckStatus = .pending
    @State private var schemaStatus: CheckStatus = .pending
    @State private var contactsStatus: CheckStatus = .pending

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First-Run Setup").font(.title2).bold()
            CheckRow(title: "Read ~/Library/Messages/chat.db", status: dbStatus, action: "Grant Full Disk Access in System Settings → Privacy & Security → Full Disk Access")
            CheckRow(title: "Supported schema", status: schemaStatus, action: "Update app or open issue with Diagnostic Report")
            CheckRow(title: "Contacts permission (optional)", status: contactsStatus, action: "Enable contact names in-app; denied permission falls back to handles")

            HStack {
                Button("Retry") { Task { await runChecks() } }
                Button("Open Diagnostics") { appState.showDiagnostics = true }
                Spacer()
                Button("Continue") { appState.markSetupCompleted() }
                    .disabled(!(dbStatus == .pass && schemaStatus == .pass))
            }
        }
        .padding(24)
        .task { await runChecks() }
    }

    private func runChecks() async {
        do {
            let path = MessagesDataStore.resolveDBPath(useSynthetic: false)
            let db = try SQLiteReadOnly(path: path)
            appState.diagnosticsStore.updateFileAccess(path: path, opened: true)
            dbStatus = .pass
            let probe = try SchemaProbe.probe(db: db)
            appState.diagnosticsStore.updateSchema(probe)
            schemaStatus = probe.isSupported ? .pass : .fail
        } catch {
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
        }
        contactsStatus = appState.contactResolver.status() == .authorized ? .pass : .warn
    }
}

enum CheckStatus { case pending, pass, fail, warn }

struct CheckRow: View {
    let title: String
    let status: CheckStatus
    let action: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(action).foregroundStyle(.secondary).font(.caption)
            }
        }
    }

    private var icon: String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.octagon.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .pending: return "clock"
        }
    }

    private var color: Color {
        switch status {
        case .pass: return .green
        case .fail: return .red
        case .warn: return .orange
        case .pending: return .gray
        }
    }
}
