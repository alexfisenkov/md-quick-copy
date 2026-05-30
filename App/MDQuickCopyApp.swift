import AppKit
import SwiftUI

@main
struct MDQuickCopyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @State private var copiedCommand: MaintenanceCommand?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            Divider()

            HStack(alignment: .top, spacing: 22) {
                statusPanel
                actionPanel
            }

            Spacer()
        }
        .padding(28)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("MD Quick Copy")
                    .font(.largeTitle.weight(.semibold))
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openRepository()
            } label: {
                Label("GitHub", systemImage: "arrow.up.right.square")
            }
            .controlSize(.large)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            statusRow(
                title: "Application",
                value: installedAppExists ? "/Applications" : "Not installed in /Applications",
                isOK: installedAppExists
            )

            statusRow(
                title: "Preview extension",
                value: installedExtensionExists ? "Installed bundle found" : "Install or update required",
                isOK: installedExtensionExists
            )

            statusRow(
                title: "Renderer",
                value: "Native SwiftUI/AppKit",
                isOK: true
            )

            statusRow(
                title: "Clipboard",
                value: "Code, Markdown tables, CSV, TSV",
                isOK: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maintenance")
                .font(.headline)

            ForEach(MaintenanceCommand.allCases) { command in
                Button {
                    copy(command)
                } label: {
                    Label(
                        copiedCommand == command ? "Copied" : command.title,
                        systemImage: copiedCommand == command ? "checkmark" : command.systemImage
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(command.helpText)
            }

            Button {
                showInstalledAppInFinder()
            } label: {
                Label("Show in Finder", systemImage: "finder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!installedAppExists)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func statusRow(title: String, value: String, isOK: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isOK ? .green : .orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var installedAppExists: Bool {
        FileManager.default.fileExists(atPath: "/Applications/MD Quick Copy.app")
    }

    private var installedExtensionExists: Bool {
        FileManager.default.fileExists(
            atPath: "/Applications/MD Quick Copy.app/Contents/PlugIns/MD Quick Copy Preview Extension.appex"
        )
    }

    private func openRepository() {
        if let url = URL(string: "https://github.com/alexfisenkov/md-quick-copy") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showInstalledAppInFinder() {
        let url = URL(fileURLWithPath: "/Applications/MD Quick Copy.app")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copy(_ command: MaintenanceCommand) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command.command, forType: .string)
        copiedCommand = command

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedCommand == command {
                copiedCommand = nil
            }
        }
    }
}

private enum MaintenanceCommand: String, CaseIterable, Identifiable {
    case install
    case update
    case resetQuickLook
    case uninstall

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .install:
            return "Copy install command"
        case .update:
            return "Copy update command"
        case .resetQuickLook:
            return "Copy Quick Look reset"
        case .uninstall:
            return "Copy uninstall command"
        }
    }

    var systemImage: String {
        switch self {
        case .install:
            return "square.and.arrow.down"
        case .update:
            return "arrow.triangle.2.circlepath"
        case .resetQuickLook:
            return "eye"
        case .uninstall:
            return "trash"
        }
    }

    var helpText: String {
        switch self {
        case .install:
            return "Copy a fresh clone and install command"
        case .update:
            return "Copy the standard repository update command"
        case .resetQuickLook:
            return "Copy the macOS Quick Look cache reset command"
        case .uninstall:
            return "Copy the app and extension removal command"
        }
    }

    var command: String {
        switch self {
        case .install:
            return """
            git clone https://github.com/alexfisenkov/md-quick-copy.git
            cd md-quick-copy
            ./script/install_app.sh
            """
        case .update:
            return """
            cd md-quick-copy
            git pull
            ./script/install_app.sh
            """
        case .resetQuickLook:
            return """
            qlmanage -r
            qlmanage -r cache
            """
        case .uninstall:
            return """
            pluginkit -r "/Applications/MD Quick Copy.app/Contents/PlugIns/MD Quick Copy Preview Extension.appex" || true
            rm -rf "/Applications/MD Quick Copy.app"
            qlmanage -r
            qlmanage -r cache
            """
        }
    }
}
