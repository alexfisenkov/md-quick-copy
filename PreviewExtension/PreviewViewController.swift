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
        } else if let heading = heading(line) {
            headingView(level: heading.level, text: heading.text)
        } else if let task = taskListItem(line) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.body.weight(.medium))
                    .foregroundStyle(task.isDone ? .green : .secondary)
                    .frame(width: 16)
                Text(inlineMarkdown(task.text))
            }
            .font(.body)
        } else if let unordered = unorderedListItem(line) {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body.weight(.medium))
                Text(inlineMarkdown(unordered))
            }
            .font(.body)
        } else if let ordered = orderedListItem(line) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(ordered.number).")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(inlineMarkdown(ordered.text))
            }
            .font(.body)
        } else if let quote = blockquote(line) {
            Text(inlineMarkdown(quote))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 3)
                }
        } else if isHorizontalRule(line) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .padding(.vertical, 7)
        } else {
            Text(inlineMarkdown(line))
                .font(.body)
        }
    }

    @ViewBuilder
    private func headingView(level: Int, text: String) -> some View {
        Text(inlineMarkdown(text))
            .font(.system(size: headingSize(level), weight: .semibold))
            .padding(.bottom, level == 1 ? 5 : 0)
            .overlay(alignment: .bottom) {
                if level == 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
            }
    }

    private func heading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }

        return (level, String(line.dropFirst(level + 1)))
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 30
        case 2: return 22
        case 3: return 18
        case 4: return 16
        default: return 15
        }
    }

    private func unorderedListItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private func taskListItem(_ line: String) -> (isDone: Bool, text: String)? {
        guard let content = unorderedListItem(line) else {
            return nil
        }

        if content.hasPrefix("[ ] ") {
            return (false, String(content.dropFirst(4)))
        }
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return (true, String(content.dropFirst(4)))
        }

        return nil
    }

    private func orderedListItem(_ line: String) -> (number: String, text: String)? {
        guard let markerIndex = line.firstIndex(of: ".") else {
            return nil
        }

        let number = line[..<markerIndex]
        let textStart = line.index(after: markerIndex)
        guard !number.isEmpty,
              number.allSatisfy(\.isNumber),
              textStart < line.endIndex,
              line[textStart] == " " else {
            return nil
        }

        return (String(number), String(line[line.index(after: textStart)...]))
    }

    private func blockquote(_ line: String) -> String? {
        if line.hasPrefix("> ") {
            return String(line.dropFirst(2))
        }
        if line == ">" {
            return ""
        }
        return nil
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let collapsed = line.replacingOccurrences(of: " ", with: "")
        return collapsed.count >= 3 &&
            (collapsed.allSatisfy { $0 == "-" } ||
             collapsed.allSatisfy { $0 == "*" } ||
             collapsed.allSatisfy { $0 == "_" })
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

private struct TableBlockView: View {
    let table: MarkdownTable

    var body: some View {
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
    (try? AttributedString(markdown: text)) ?? AttributedString(text)
}
