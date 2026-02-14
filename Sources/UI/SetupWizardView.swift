import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject var appState: AppState
    @State private var dbStatus: CheckStatus = .pending
    @State private var schemaStatus: CheckStatus = .pending
    @State private var contactsStatus: CheckStatus = .pending
    @State private var statusMessage = ""
    @State private var requestedContacts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First-Run Setup").font(.title2).bold()
            CheckRow(title: "Read ~/Library/Messages/chat.db", status: dbStatus, action: "System Settings → Privacy & Security → Full Disk Access → enable this app")
            CheckRow(title: "Supported schema", status: schemaStatus, action: "If unsupported: copy diagnostics report and open a GitHub issue")
            CheckRow(title: "Contacts permission", status: contactsStatus, action: "Allow Contacts so names resolve by default")
            if !statusMessage.isEmpty {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Retry") { Task { await runChecks() } }
                Button("Open System Settings") { SystemSettingsLink.openFullDiskAccess() }
                Button("Request Contacts Access") { Task { await requestContactsAccess() } }
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
            if probe.isSupported {
                appState.diagnosticsStore.clearLastError()
                statusMessage = "Database access and schema probe passed."
            } else {
                appState.diagnosticsStore.setLastError(.schemaMismatch)
                statusMessage = "Unsupported Messages schema detected. Open Diagnostics for column details."
            }
            AppLogger.info("Startup", "First-run checks completed")
        } catch DBError.fileMissing {
            appState.diagnosticsStore.setLastError(.missingFile)
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "chat.db not found at expected path."
            AppLogger.error("Startup", "First-run check failed: missing chat.db")
        } catch DBError.openFailed {
            appState.diagnosticsStore.setLastError(.permission)
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "Full Disk Access is likely required."
            AppLogger.error("Startup", "First-run check failed: likely missing Full Disk Access")
        } catch {
            appState.diagnosticsStore.setLastError(.unknown)
            appState.diagnosticsStore.updateFileAccess(path: MessagesDataStore.resolveDBPath(useSynthetic: false), opened: false)
            dbStatus = .fail
            schemaStatus = .fail
            statusMessage = "Unexpected setup check error: \(error.localizedDescription)"
            AppLogger.error("Startup", "First-run check failed: \(error.localizedDescription)")
        }
        contactsStatus = appState.contactResolver.status() == .authorized ? .pass : .fail
        if appState.resolveContactNames, !requestedContacts, appState.contactResolver.status() == .notDetermined {
            requestedContacts = true
            await requestContactsAccess()
        }
    }

    private func requestContactsAccess() async {
        let granted = await appState.contactResolver.requestIfNeeded()
        if granted {
            contactsStatus = .pass
            statusMessage = "Contacts access granted."
        } else {
            contactsStatus = .fail
            appState.setResolveContactNames(false)
            statusMessage = "Contacts denied. Falling back to handles."
        }
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
