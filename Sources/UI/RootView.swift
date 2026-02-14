import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasValidBundleIdentifier {
                LaunchGuardView()
            } else if appState.setupCompleted {
                MainShellView()
            } else {
                SetupWizardView()
            }
        }
        .sheet(isPresented: $appState.showDiagnostics) {
            DiagnosticsView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 520)
        }
        .sheet(isPresented: $appState.showPermissionSettings) {
            PermissionSettingsView()
                .environmentObject(appState)
                .frame(minWidth: 640, minHeight: 420)
        }
    }
}

struct LaunchGuardView: View {
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launch From .app Bundle Required")
                .font(.title2)
                .bold()

            Text("This build was started without a bundle identifier. Permissions and Contacts integration require launching the generated .app bundle.")
                .foregroundStyle(.secondary)

            Text("Run:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("./scripts/create-app-bundle.sh release\nopen .build/release/MessageExporterApp.app\n# or build/run from MessageExporterApp.xcodeproj in Xcode")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack {
                Button("Build + Launch App Bundle") {
                    launchViaScript()
                }
                Button("Open Existing .app") {
                    openExistingBundle()
                }
                Button("Copy Run Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("./scripts/run-app.sh release", forType: .string)
                    statusMessage = "Copied ./scripts/run-app.sh release"
                }
                Button("Open Project Folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
                }
                Spacer()
            }
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openExistingBundle() {
        guard let root = findWorkspaceRoot() else {
            statusMessage = "Could not locate workspace root."
            return
        }
        let appPath = root + "/.build/release/MessageExporterApp.app"
        guard FileManager.default.fileExists(atPath: appPath) else {
            statusMessage = "No app bundle found. Click Build + Launch App Bundle first."
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
        NSApp.terminate(nil)
    }

    private func launchViaScript() {
        guard let root = findWorkspaceRoot() else {
            statusMessage = "Could not locate workspace root."
            return
        }

        statusMessage = "Building app bundle..."
        DispatchQueue.global(qos: .userInitiated).async {
            let escapedRoot = root.replacingOccurrences(of: "'", with: "'\\''")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [
                "-lc",
                "cd '\(escapedRoot)' && ./scripts/run-app.sh release"
            ]
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        NSApp.terminate(nil)
                    } else {
                        statusMessage = "Build/launch failed. Run ./scripts/run-app.sh release in Terminal."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    statusMessage = "Failed to launch script: \(error.localizedDescription)"
                }
            }
        }
    }

    private func findWorkspaceRoot() -> String? {
        let fm = FileManager.default
        var candidates: [String] = [fm.currentDirectoryPath]

        if let executablePath = Bundle.main.executableURL?.path {
            let executableURL = URL(fileURLWithPath: executablePath)
            let candidate = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            candidates.append(candidate)
        }

        for path in candidates {
            var probe = URL(fileURLWithPath: path)
            for _ in 0..<6 {
                let scriptPath = probe.appendingPathComponent("scripts/create-app-bundle.sh").path
                if fm.fileExists(atPath: scriptPath) {
                    return probe.path
                }
                probe.deleteLastPathComponent()
            }
        }
        return nil
    }
}
