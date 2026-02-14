import SwiftUI

struct MainShellView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var showExport = false
    @State private var transientStatus = ""
    @State private var resolvedTitles: [String: String] = [:]

    private var filtered: [ConversationSummary] {
        if search.isEmpty { return appState.dataStore.conversations }
        return appState.dataStore.conversations.filter {
            titleForConversation($0).localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $appState.selectedConversation) { convo in
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleForConversation(convo)).lineLimit(1)
                    Text(convo.lastPreview ?? "No preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Export Conversation") {
                        appState.selectedConversation = convo
                        showExport = true
                    }
                }
                .onAppear {
                    if convo.id == appState.dataStore.conversations.last?.id {
                        Task { await appState.dataStore.loadMore() }
                    }
                }
            }
            .overlay {
                if appState.dataStore.isLoading && appState.dataStore.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                }
            }
            .searchable(text: $search)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { appState.showDiagnostics = true } label: { Image(systemName: "info.circle") }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Export") { showExport = true }
                        .disabled(appState.selectedConversation == nil)
                }
                ToolbarItem(placement: .automatic) {
                    Menu("View") {
                        Toggle("Privacy Mode", isOn: $appState.privacyModeEnabled)
                        Toggle("Resolve Contact Names", isOn: Binding(
                            get: { appState.resolveContactNames },
                            set: { newValue in
                                appState.setResolveContactNames(newValue)
                                Task { await handleContactToggle(newValue) }
                            }
                        ))
                    }
                }
            }
        } detail: {
            if let selected = appState.selectedConversation {
                ConversationDetailView(conversation: selected)
            } else {
                ContentUnavailableView("Select a Conversation", systemImage: "message")
            }
        }
        .sheet(isPresented: $showExport) {
            if let selected = appState.selectedConversation {
                ExportView(conversation: selected)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                if appState.dataStore.isLoading && !appState.dataStore.conversations.isEmpty {
                    ProgressView("Loading more...")
                }
                if let err = appState.dataStore.errorMessage {
                    HStack {
                        Text(err).font(.caption)
                        Spacer()
                        if err.localizedCaseInsensitiveContains("disk access") {
                            Button("Open Settings") { SystemSettingsLink.openFullDiskAccess() }
                                .font(.caption)
                        }
                    }
                    .padding(8)
                    .background(.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if !transientStatus.isEmpty {
                    Text(transientStatus)
                        .font(.caption)
                        .padding(8)
                        .background(.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
        }
        .padding()
        }
        .task { await appState.dataStore.resetAndLoad() }
        .task(id: appState.resolveContactNames) {
            await refreshResolvedTitles()
        }
        .task(id: appState.dataStore.conversations.count) {
            if appState.resolveContactNames {
                await refreshResolvedTitles()
            }
        }
    }

    private func titleForConversation(_ conversation: ConversationSummary) -> String {
        guard appState.resolveContactNames else {
            return conversation.title
        }
        return resolvedTitles[conversation.id] ?? conversation.title
    }

    private func handleContactToggle(_ enabled: Bool) async {
        guard enabled else {
            resolvedTitles = [:]
            return
        }
        let status = appState.contactResolver.status()
        if status == .authorized {
            await refreshResolvedTitles()
            return
        }
        let granted = await appState.contactResolver.requestIfNeeded()
        if granted {
            transientStatus = "Contacts access granted."
            await refreshResolvedTitles()
            AppLogger.info("Contacts", "Contacts permission granted")
        } else {
            appState.setResolveContactNames(false)
            resolvedTitles = [:]
            transientStatus = "Contacts permission denied. Falling back to handles."
            AppLogger.info("Contacts", "Contacts permission denied; using handles")
        }
    }

    private func refreshResolvedTitles() async {
        guard appState.resolveContactNames else {
            resolvedTitles = [:]
            return
        }
        guard appState.contactResolver.status() == .authorized else {
            resolvedTitles = [:]
            return
        }

        await appState.contactResolver.prepareIndexIfNeeded()

        var map: [String: String] = [:]
        for conversation in appState.dataStore.conversations {
            let resolved = conversation.participantHandles.map { appState.contactResolver.resolve(handle: $0) }
            if !resolved.isEmpty {
                map[conversation.id] = resolved.prefix(3).joined(separator: ", ")
            }
        }
        resolvedTitles = map
    }
}

struct ConversationDetailView: View {
    @EnvironmentObject var appState: AppState
    let conversation: ConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(conversation.title).font(.title3).bold()
            Text("Participants: \(participantsSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.privacyModeEnabled {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(Text("Privacy Mode: content hidden"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select Export to generate transcript files for this conversation.")
                Spacer()
            }
        }
        .padding()
    }

    private var participantsSummary: String {
        if conversation.participantHandles.isEmpty {
            return "Unknown"
        }
        return conversation.participantHandles.prefix(5).joined(separator: ", ")
    }
}
