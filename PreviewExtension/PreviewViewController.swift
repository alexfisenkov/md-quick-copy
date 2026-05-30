import Cocoa
import MDQuickCopyCore
import QuickLookUI
import SwiftUI

@MainActor
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var hostingView: NSHostingView<MarkdownPreviewView>!

    override func loadView() {
        let hostingView = NSHostingView(rootView: MarkdownPreviewView(title: "", blocks: [], openURL: { _ in }))
        self.hostingView = hostingView
        view = hostingView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try readMarkdown(at: url)
            hostingView.rootView = MarkdownPreviewView(
                title: url.lastPathComponent,
                blocks: MarkdownBlockParser.parse(markdown),
                openURL: { [weak self] url in
                    self?.open(url)
                }
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

    private func open(_ url: URL) {
        guard let extensionContext else {
            copyURLToPasteboard(url)
            return
        }

        extensionContext.open(url) { success in
            guard !success else {
                return
            }

            DispatchQueue.main.async {
                self.copyURLToPasteboard(url)
            }
        }
    }

    private func copyURLToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
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
    let openURL: (URL) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if outline.count >= 2 {
                    OutlineBlockView(items: outline)
                }

                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .markdown(let text):
                        MarkdownTextBlock(text: text, openURL: openURL)
                    case .code(let language, let text):
                        CodeBlockView(language: language, code: text)
                    case .table(let table):
                        TableBlockView(table: table)
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

    private var outline: [MarkdownOutlineItem] {
        MarkdownOutlineBuilder.build(from: blocks)
    }
}

private struct MarkdownTextBlock: View {
    let text: String
    let openURL: (URL) -> Void
    @State private var measuredHeight: CGFloat = 1
    @State private var selectedText = ""
    @State private var copiedSelection = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SelectableAttributedTextView(
                attributedText: MarkdownPreviewAttributedTextRenderer.render(text),
                openURL: openURL,
                measuredHeight: $measuredHeight,
                selectedText: $selectedText
            )
            .frame(maxWidth: .infinity, minHeight: measuredHeight, maxHeight: measuredHeight)

            if !selectedText.isEmpty {
                Button {
                    copySelection()
                } label: {
                    Label(
                        copiedSelection ? "Copied" : "Copy selection",
                        systemImage: copiedSelection ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(6)
                .background(.regularMaterial, in: Capsule())
            }
        }
    }

    private func copySelection() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)
        copiedSelection = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copiedSelection = false
            selectedText = ""
        }
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

private struct OutlineBlockView: View {
    let items: [MarkdownOutlineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.secondary)
                Text("Contents")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item.title)
                        .font(.system(size: fontSize(for: item.level), weight: item.level <= 2 ? .semibold : .regular))
                        .foregroundStyle(item.level == 1 ? .primary : .secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .padding(.leading, CGFloat(max(item.level - 1, 0)) * 13)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 14
        case 2: return 13
        default: return 12
        }
    }
}

private struct TableBlockView: View {
    let table: MarkdownTable
    @State private var copiedFormat: TableCopyFormat?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label("Table", systemImage: "tablecells")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                ForEach(TableCopyFormat.allCases) { format in
                    Button {
                        copy(format)
                    } label: {
                        Label(
                            copiedFormat == format ? "Copied" : format.rawValue,
                            systemImage: copiedFormat == format ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy table as \(format.helpText)")
                }
            }

            ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(Array(table.headers.enumerated()), id: \.offset) { column, value in
                            tableCell(value, column: column, isHeader: true)
                        }
                    }

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(0..<table.headers.count, id: \.self) { column in
                                tableCell(rowValue(row, column), column: column, isHeader: false)
                            }
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
        }
    }

    private func rowValue(_ row: [String], _ column: Int) -> String {
        column < row.count ? row[column] : ""
    }

    private func tableCell(_ text: String, column: Int, isHeader: Bool) -> some View {
        Text(inlineMarkdown(text))
            .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
            .textSelection(.enabled)
            .lineLimit(nil)
            .frame(width: columnWidth(column), alignment: table.alignments[safe: column]?.frameAlignment ?? .leading)
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 0.5)
    }

    private func columnWidth(_ column: Int) -> CGFloat {
        switch column {
        case 0:
            return 210
        default:
            return 180
        }
    }

    private func copy(_ format: TableCopyFormat) {
        let text: String
        switch format {
        case .markdown:
            text = MarkdownTableExporter.markdown(table)
        case .csv:
            text = MarkdownTableExporter.csv(table)
        case .tsv:
            text = MarkdownTableExporter.tsv(table)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedFormat = format

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedFormat == format {
                copiedFormat = nil
            }
        }
    }
}

private enum TableCopyFormat: String, CaseIterable, Identifiable {
    case markdown = "MD"
    case csv = "CSV"
    case tsv = "TSV"

    var id: String {
        rawValue
    }

    var helpText: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .csv:
            return "CSV"
        case .tsv:
            return "TSV"
        }
    }
}

private extension MarkdownTableAlignment {
    var frameAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private func inlineMarkdown(_ text: String) -> AttributedString {
    MarkdownAttributedStringBuilder.build(text)
}
