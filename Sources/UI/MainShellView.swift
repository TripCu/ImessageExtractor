import SwiftUI

struct MainShellView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var showExport = false

    var filtered: [ConversationSummary] {
        if search.isEmpty { return appState.dataStore.conversations }
        return appState.dataStore.conversations.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $appState.selectedConversation) { convo in
                VStack(alignment: .leading) {
                    Text(convo.title).lineLimit(1)
                    Text(convo.lastPreview ?? "No preview").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .onAppear {
                    if convo.id == appState.dataStore.conversations.last?.id {
                        Task { await appState.dataStore.loadMore() }
                    }
                }
            }
            .searchable(text: $search)
            .toolbar {
                ToolbarItem(placement: .automatic) { Button { appState.showDiagnostics = true } label: { Image(systemName: "info.circle") } }
                ToolbarItem(placement: .automatic) { Button("Export") { showExport = true }.disabled(appState.selectedConversation == nil) }
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
            if let err = appState.dataStore.errorMessage {
                Text(err).font(.caption).padding(8).background(.red.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 8)).padding()
            }
        }
        .task { await appState.dataStore.resetAndLoad() }
    }
}

struct ConversationDetailView: View {
    @EnvironmentObject var appState: AppState
    let conversation: ConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(conversation.title).font(.title3).bold()
            if appState.privacyModeEnabled {
                RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(Text("Privacy Mode: content hidden")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Conversation preview is enabled for local export operations.")
                Spacer()
            }
        }
        .padding()
    }
}
