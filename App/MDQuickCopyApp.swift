import SwiftUI

@main
struct MDQuickCopyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, minHeight: 280)
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MD Quick Copy")
                .font(.largeTitle.weight(.semibold))

            Text("Quick Look renderer for Markdown files with visible copy buttons on code blocks.")
                .font(.body)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Usage")
                    .font(.headline)
                Text("Select a .md file in Finder and press Space.")
                Text("Click Copy on any code block to place that block on the macOS clipboard.")
            }
            .font(.body)

            Spacer()
        }
        .padding(28)
    }
}
