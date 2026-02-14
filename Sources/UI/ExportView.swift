import SwiftUI

struct ExportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let conversation: ConversationSummary
    @State private var format: ExportFormat = .json
    @State private var passphrase = ""
    @State private var status = ""
    @State private var exporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export \(conversation.title)").font(.headline)
            Picker("Format", selection: $format) {
                Text("Text").tag(ExportFormat.text)
                Text("JSON").tag(ExportFormat.json)
                Text("SQLite").tag(ExportFormat.sqlite)
                Text("Encrypted (.imexport)").tag(ExportFormat.encrypted)
            }
            if format == .encrypted {
                SecureField("Passphrase", text: $passphrase)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Export") { Task { await runExport() } }.disabled(exporting)
            }
            if !status.isEmpty { Text(status).font(.caption) }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func runExport() async {
        exporting = true
        defer { exporting = false }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "conversation-\(conversation.id).\(extensionForFormat(format))"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let messages = await appState.dataStore.messages(for: conversation)
        let bundle = ExportBundle(conversation: conversation, messages: messages)
        let exporter = Exporter()
        do {
            switch format {
            case .text: try exporter.exportText(bundle: bundle, to: url)
            case .json: try exporter.exportJSON(bundle: bundle, to: url)
            case .sqlite: try exporter.exportSQLite(bundle: bundle, to: url)
            case .encrypted:
                let data = try JSONEncoder.pretty.encode(bundle)
                let encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: passphrase)
                try encrypted.write(to: url, options: .withoutOverwriting)
            }
            status = "Export completed."
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func extensionForFormat(_ f: ExportFormat) -> String {
        switch f {
        case .text: return "txt"
        case .json: return "json"
        case .sqlite: return "sqlite"
        case .encrypted: return "imexport"
        }
    }
}
