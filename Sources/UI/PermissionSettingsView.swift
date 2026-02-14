import SwiftUI

struct PermissionSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var dbStatus: CheckStatus = .pending
    @State private var schemaStatus: CheckStatus = .pending
    @State private var contactsStatus: CheckStatus = .pending
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permissions & Access").font(.title3).bold()
            CheckRow(title: "Full Disk Access", status: dbStatus, action: "System Settings → Privacy & Security → Full Disk Access")
            CheckRow(title: "Messages schema support", status: schemaStatus, action: "Detect unsupported macOS schema changes early")
            CheckRow(title: "Contacts access", status: contactsStatus, action: "Resolve participant names from Contacts")

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh Status") { Task { await runChecks() } }
                Button("Grant Full Disk Access") { SystemSettingsLink.openFullDiskAccess() }
                Button("Grant Contacts Access") { Task { await requestContactsAccess() } }
                Button("Open Diagnostics") { appState.showDiagnostics = true }
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .task { await runChecks() }
    }

    private func runChecks() async {
        guard appState.hasValidBundleIdentifier else {
            dbStatus = .fail
            schemaStatus = .fail
            contactsStatus = .fail
            statusMessage = "App is not running from a .app bundle. Use scripts/run-app.sh or run from Xcode."
            return
        }

        do {
            let path = MessagesDataStore.resolveDBPath(useSynthetic: false)
            let db = try SQLiteReadOnly(path: path)
            appState.diagnosticsStore.updateFileAccess(path: path, opened: true)
            dbStatus = .pass

            let probe = try SchemaProbe.probe(db: db)
            appState.diagnosticsStore.updateSchema(probe)
            schemaStatus = probe.isSupported ? .pass : .fail
            statusMessage = probe.isSupported
                ? "Database access is healthy."
                : "Unsupported Messages schema detected. Open Diagnostics for details."
        } catch DBError.fileMissing {
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "chat.db was not found."
        } catch DBError.openFailed {
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "Full Disk Access is required."
        } catch {
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "Unexpected error: \(error.localizedDescription)"
        }

        contactsStatus = appState.contactResolver.status() == .authorized ? .pass : .fail
    }

    private func requestContactsAccess() async {
        let granted = await appState.contactResolver.requestIfNeeded()
        contactsStatus = granted ? .pass : .fail
        statusMessage = granted ? "Contacts access granted." : "Contacts access denied."
    }
}
