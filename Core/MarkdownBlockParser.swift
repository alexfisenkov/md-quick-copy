import Foundation

public enum MarkdownTableAlignment: Equatable {
    case leading
    case center
    case trailing
}

public struct MarkdownTable: Equatable {
    public let headers: [String]
    public let alignments: [MarkdownTableAlignment]
    public let rows: [[String]]

    public init(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]]) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
    }
}

public enum MarkdownBlock: Equatable {
    case markdown(String)
    case code(language: String?, text: String)
    case table(MarkdownTable)
}

public enum MarkdownBlockParser {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var markdownLines: [String] = []
        let lines = markdown.components(separatedBy: .newlines)
        var index = 0

        func flushMarkdown() {
            let text = markdownLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.markdown(text))
            }
            markdownLines.removeAll(keepingCapacity: true)
        }

        while index < lines.count {
            let line = lines[index]

            if let fence = fenceOpening(in: line) {
                flushMarkdown()
                let parsed = parseFencedCode(lines: lines, start: index, fence: fence)
                blocks.append(.code(language: parsed.language, text: parsed.code))
                index = parsed.nextIndex
                continue
            }

            if let parsed = parseTable(lines: lines, start: index) {
                flushMarkdown()
                blocks.append(.table(parsed.table))
                index = parsed.nextIndex
                continue
            }

            if let language = exportedLanguageLabel(line),
               let firstCodeIndex = nextNonEmptyLineIndex(in: lines, after: index),
               looksLikeCodeLine(lines[firstCodeIndex]) {
                flushMarkdown()
                let parsed = parseExportedCode(lines: lines, start: firstCodeIndex)
                blocks.append(.code(language: language, text: parsed.code))
                index = parsed.nextIndex
                continue
            }

            if isIndentedCodeLine(line) {
                flushMarkdown()
                let parsed = parseIndentedCode(lines: lines, start: index)
                blocks.append(.code(language: nil, text: parsed.code))
                index = parsed.nextIndex
                continue
            }

            markdownLines.append(line)
            index += 1
        }

        flushMarkdown()

        return blocks
    }

    private struct Fence {
        let marker: Character
        let length: Int
        let language: String?
    }

    private static func fenceOpening(in line: String) -> Fence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "`" || first == "~" else {
            return nil
        }

        let markerLength = trimmed.prefix { $0 == first }.count
        guard markerLength >= 3 else {
            return nil
        }

        let language = trimmed
            .dropFirst(markerLength)
            .trimmingCharacters(in: .whitespaces)

        return Fence(
            marker: first,
            length: markerLength,
            language: language.isEmpty ? nil : String(language)
        )
    }

    private static func closesFence(_ line: String, fence: Fence) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.prefix { $0 == fence.marker }.count >= fence.length
    }

    private static func parseFencedCode(
        lines: [String],
        start: Int,
        fence: Fence
    ) -> (language: String?, code: String, nextIndex: Int) {
        var codeLines: [String] = []
        var index = start + 1

        while index < lines.count {
            if closesFence(lines[index], fence: fence) {
                return (fence.language, codeLines.joined(separator: "\n"), index + 1)
            }

            codeLines.append(lines[index])
            index += 1
        }

        return (fence.language, codeLines.joined(separator: "\n"), index)
    }

    private static func parseTable(
        lines: [String],
        start: Int
    ) -> (table: MarkdownTable, nextIndex: Int)? {
        guard start + 1 < lines.count,
              let headers = parseTableRow(lines[start]),
              let alignments = parseTableSeparator(lines[start + 1]),
              headers.count >= 2 else {
            return nil
        }

        var rows: [[String]] = []
        var index = start + 2

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let row = parseTableRow(lines[index]) else {
                break
            }
            rows.append(padded(row, to: headers.count))
            index += 1
        }

        let normalizedAlignments = padded(alignments, to: headers.count, fill: .leading)
        return (
            MarkdownTable(
                headers: padded(headers, to: headers.count),
                alignments: normalizedAlignments,
                rows: rows
            ),
            index
        )
    }

    private static func parseTableRow(_ line: String) -> [String]? {
        let trimmed = trimTrailingWhitespace(line).trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else {
            return nil
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in trimmed {
            if character == "|" && !isEscaped {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current.removeAll(keepingCapacity: true)
            } else if character == "\\" && !isEscaped {
                isEscaped = true
            } else {
                if isEscaped {
                    if character == "|" {
                        current.append(character)
                    } else {
                        current.append("\\")
                        current.append(character)
                    }
                    isEscaped = false
                } else {
                    current.append(character)
                }
            }
        }

        if isEscaped {
            current.append("\\")
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))

        if trimmed.hasPrefix("|"), cells.first == "" {
            cells.removeFirst()
        }
        if trimmed.hasSuffix("|"), cells.last == "" {
            cells.removeLast()
        }

        return cells.isEmpty ? nil : cells
    }

    private static func parseTableSeparator(_ line: String) -> [MarkdownTableAlignment]? {
        guard let cells = parseTableRow(line) else {
            return nil
        }

        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let marker = cell.trimmingCharacters(in: .whitespaces)
            guard marker.contains("-"),
                  marker.allSatisfy({ $0 == "-" || $0 == ":" }) else {
                return nil
            }

            if marker.hasPrefix(":"), marker.hasSuffix(":") {
                alignments.append(.center)
            } else if marker.hasSuffix(":") {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }

        return alignments
    }

    private static func exportedLanguageLabel(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let knownLabels: Set<String> = [
            "bash", "c", "css", "dockerfile", "go", "html", "ini", "ini, toml",
            "javascript", "json", "nginx", "python", "shell", "sql", "swift",
            "toml", "typescript", "xml", "yaml", "yml"
        ]

        return knownLabels.contains(trimmed.lowercased()) ? trimmed : nil
    }

    private static func parseExportedCode(
        lines: [String],
        start: Int
    ) -> (code: String, nextIndex: Int) {
        var codeLines: [String] = []
        var index = start

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if let nextIndex = nextNonEmptyLineIndex(in: lines, after: index) {
                    let nextLine = lines[nextIndex]
                    if isHeadingLine(nextLine) || !looksLikeCodeLine(nextLine) {
                        index = nextIndex
                        break
                    }
                }
                codeLines.append("")
                index += 1
                continue
            }

            if isHeadingLine(line) || (!looksLikeCodeLine(line) && !codeLines.isEmpty) {
                break
            }

            codeLines.append(normalizeExportedCodeLine(line))
            index += 1
        }

        while codeLines.last == "" {
            codeLines.removeLast()
        }

        return (codeLines.joined(separator: "\n"), index)
    }

    private static func parseIndentedCode(
        lines: [String],
        start: Int
    ) -> (code: String, nextIndex: Int) {
        var codeLines: [String] = []
        var index = start

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                codeLines.append("")
                index += 1
            } else if isIndentedCodeLine(line) {
                codeLines.append(stripCodeIndent(line))
                index += 1
            } else {
                break
            }
        }

        while codeLines.last == "" {
            codeLines.removeLast()
        }

        return (codeLines.joined(separator: "\n"), index)
    }

    private static func isIndentedCodeLine(_ line: String) -> Bool {
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    private static func stripCodeIndent(_ line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        if line.hasPrefix("    ") {
            return String(line.dropFirst(4))
        }
        return line
    }

    private static func looksLikeCodeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return false
        }

        return line.hasPrefix(" ") ||
            line.hasPrefix("\t") ||
            trimmed.hasPrefix("{") ||
            trimmed.hasPrefix("}") ||
            trimmed.hasPrefix("[") ||
            trimmed.hasPrefix("]") ||
            trimmed.hasPrefix("\\]") ||
            trimmed.hasPrefix("#") ||
            trimmed.hasPrefix("\\#") ||
            trimmed.contains("=") ||
            trimmed.contains(#"":"#) ||
            trimmed.hasSuffix(",") ||
            trimmed.contains("{") ||
            trimmed.contains("}")
    }

    private static func isHeadingLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else {
            return false
        }

        let markerLength = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(markerLength) else {
            return false
        }

        return trimmed.dropFirst(markerLength).first == " "
    }

    private static func nextNonEmptyLineIndex(in lines: [String], after index: Int) -> Int? {
        var candidate = index + 1
        while candidate < lines.count {
            if !lines[candidate].trimmingCharacters(in: .whitespaces).isEmpty {
                return candidate
            }
            candidate += 1
        }
        return nil
    }

    private static func normalizeExportedCodeLine(_ line: String) -> String {
        var normalized = trimTrailingWhitespace(line)
        let replacements = [
            "\\#": "#",
            "\\=": "=",
            "\\_": "_",
            "\\[": "[",
            "\\]": "]",
            "\\+": "+",
            "\\-": "-",
            "\\.": ".",
            "\\`": "`"
        ]

        for (escaped, replacement) in replacements {
            normalized = normalized.replacingOccurrences(of: escaped, with: replacement)
        }

        return normalized
    }

    private static func trimTrailingWhitespace(_ line: String) -> String {
        String(line.reversed().drop { $0 == " " || $0 == "\t" }.reversed())
    }

    private static func padded<T>(_ values: [T], to count: Int, fill: T) -> [T] {
        if values.count >= count {
            return Array(values.prefix(count))
        }
        return values + Array(repeating: fill, count: count - values.count)
    }

    private static func padded(_ values: [String], to count: Int) -> [String] {
        padded(values, to: count, fill: "")
    }
}
