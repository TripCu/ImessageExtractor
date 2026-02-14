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
                Button("Export") { Task { await runExport() } }
                    .disabled(exporting || (format == .encrypted && passphrase.isEmpty))
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
        panel.nameFieldStringValue = defaultExportFilename(for: format)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let messages = await appState.dataStore.messages(for: conversation)
        let displayNames: [String]
        if appState.resolveContactNames, appState.contactResolver.status() == .authorized {
            displayNames = conversation.participantHandles.map { appState.contactResolver.resolve(handle: $0) }
        } else {
            displayNames = conversation.participantHandles
        }

        let conversationForExport = ConversationSummary(
            id: conversation.id,
            sourceRowID: conversation.sourceRowID,
            title: conversation.title,
            participantHandles: conversation.participantHandles,
            participantDisplayNames: displayNames,
            lastPreview: conversation.lastPreview,
            lastDate: conversation.lastDate,
            isGroup: conversation.isGroup
        )
        let bundle = ExportBundle(conversation: conversationForExport, messages: messages)
        let exporter = Exporter()
        do {
            switch format {
            case .text: try exporter.exportText(bundle: bundle, to: url)
            case .json: try exporter.exportJSON(bundle: bundle, to: url)
            case .sqlite: try exporter.exportSQLite(bundle: bundle, to: url)
            case .encrypted: try exporter.exportEncrypted(bundle: bundle, passphrase: passphrase, to: url)
            }
            status = "Export completed."
            AppLogger.info("Export", "Export completed")
            dismiss()
        } catch {
            status = "Export failed: \(error.localizedDescription)"
            AppLogger.error("Export", "Export failed: \(error.localizedDescription)")
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

    private func defaultExportFilename(for format: ExportFormat) -> String {
        let rawTitle = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sanitizeFilename(rawTitle.isEmpty ? "conversation" : rawTitle)
        let ts = Self.timestampFormatter.string(from: Date())
        return "message_export_\(base)_\(ts).\(extensionForFormat(format))"
    }

    private func sanitizeFilename(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let string = String(scalars).replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        return string.lowercased()
    }

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        return df
    }()
}
