import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var setupCompleted: Bool
    @Published var showDiagnostics = false
    @Published var showPermissionSettings = false
    @Published var selectedConversationKey: String?

    let defaults = UserDefaults.standard
    var dataStore: MessagesDataStore
    let contactResolver = ContactResolver()
    let diagnosticsStore = DiagnosticsStore()
    let bundleIdentifier = Bundle.main.bundleIdentifier

    var hasValidBundleIdentifier: Bool {
        guard let bundleIdentifier else { return false }
        return !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedConversation: ConversationSummary? {
        guard let key = selectedConversationKey else { return nil }
        return dataStore.conversations.first(where: { $0.selectionKey == key })
    }

    init() {
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        dataStore = MessagesDataStore(diagnostics: diagnosticsStore)
        if !hasValidBundleIdentifier {
            AppLogger.error("Startup", "Missing bundle identifier. Launch from .app bundle for proper permissions.")
        } else {
            AppLogger.info("Startup", "Bundle identifier: \(bundleIdentifier ?? "unknown")")
        }
        AppLogger.info("Startup", "App state initialized")
    }

    func markSetupCompleted() {
        setupCompleted = true
        defaults.set(true, forKey: "setupCompleted")
    }

    func clearInvalidSelectionIfNeeded() {
        guard let key = selectedConversationKey else { return }
        if !dataStore.conversations.contains(where: { $0.selectionKey == key }) {
            selectedConversationKey = nil
        }
    }
}
