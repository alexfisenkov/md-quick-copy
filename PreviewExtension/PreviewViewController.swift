import Cocoa
import MDQuickCopyCore
import QuickLookUI
import SwiftUI

@MainActor
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var hostingView: NSHostingView<MarkdownPreviewView>!

    override func loadView() {
        let hostingView = NSHostingView(rootView: MarkdownPreviewView(title: "", blocks: []))
        self.hostingView = hostingView
        view = hostingView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try readMarkdown(at: url)
            hostingView.rootView = MarkdownPreviewView(
                title: url.lastPathComponent,
                blocks: MarkdownBlockParser.parse(markdown)
            )
            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func readMarkdown(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        if let string = String(data: data, encoding: .windowsCP1251) {
            return string
        }
        if let string = String(data: data, encoding: .isoLatin1) {
            return string
        }

        throw PreviewError.unsupportedEncoding(url.lastPathComponent)
    }
}

private enum PreviewError: LocalizedError {
    case unsupportedEncoding(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding(let name):
            return "Unsupported text encoding: \(name)"
        }
    }
}

private struct MarkdownPreviewView: View {
    let title: String
    let blocks: [MarkdownBlock]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .markdown(let text):
                        MarkdownTextBlock(text: text)
                    case .code(let language, let text):
                        CodeBlockView(language: language, code: text)
                    }
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(title)
    }
}

private struct MarkdownTextBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(text.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, rawLine in
                lineView(rawLine)
            }
        }
    }

    @ViewBuilder
    private func lineView(_ rawLine: String) -> some View {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty {
            Spacer(minLength: 4)
        } else if line.hasPrefix("# ") {
            Text(inlineText(String(line.dropFirst(2))))
                .font(.system(size: 30, weight: .semibold))
                .padding(.bottom, 5)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
        } else if line.hasPrefix("## ") {
            Text(inlineText(String(line.dropFirst(3))))
                .font(.system(size: 22, weight: .semibold))
        } else if line.hasPrefix("### ") {
            Text(inlineText(String(line.dropFirst(4))))
                .font(.system(size: 18, weight: .semibold))
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 8) {
                Text("-")
                    .font(.body.weight(.medium))
                Text(inlineText(String(line.dropFirst(2))))
            }
            .font(.body)
        } else {
            Text(inlineText(line))
                .font(.body)
        }
    }

    private func inlineText(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                if let language {
                    Text(language)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    copyToPasteboard()
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}
