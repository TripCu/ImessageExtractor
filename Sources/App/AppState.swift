import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var setupCompleted: Bool
    @Published var showDiagnostics = false
    @Published var privacyModeEnabled = true
    @Published var resolveContactNames = false
    @Published var selectedConversation: ConversationSummary?

    let defaults = UserDefaults.standard
    var dataStore: MessagesDataStore
    let contactResolver = ContactResolver()
    let diagnosticsStore = DiagnosticsStore()

    init() {
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        resolveContactNames = defaults.bool(forKey: "resolveContactNames")
        dataStore = MessagesDataStore(diagnostics: diagnosticsStore)
        AppLogger.info("Startup", "App state initialized")
    }

    func markSetupCompleted() {
        setupCompleted = true
        defaults.set(true, forKey: "setupCompleted")
    }

    func setResolveContactNames(_ enabled: Bool) {
        resolveContactNames = enabled
        defaults.set(enabled, forKey: "resolveContactNames")
    }
}
