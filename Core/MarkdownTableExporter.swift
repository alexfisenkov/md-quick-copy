import Foundation

public enum MarkdownTableExporter {
    public static func markdown(_ table: MarkdownTable) -> String {
        let columnCount = table.columnCount
        let headers = normalized(table.headers, count: columnCount).map(markdownCell)
        let separator = normalized(table.alignments, count: columnCount, fill: .leading).map(alignmentMarker)
        let rows = table.rows.map { row in
            tableRow(normalized(row, count: columnCount).map(markdownCell))
        }

        return ([tableRow(headers), tableRow(separator)] + rows).joined(separator: "\n")
    }

    public static func csv(_ table: MarkdownTable) -> String {
        delimited(table, separator: ",", quoteAll: true)
    }

    public static func tsv(_ table: MarkdownTable) -> String {
        delimited(table, separator: "\t", quoteAll: false)
    }

    private static func delimited(_ table: MarkdownTable, separator: String, quoteAll: Bool) -> String {
        let columnCount = table.columnCount
        let headers = normalized(table.headers, count: columnCount)
        let rows = table.rows.map { normalized($0, count: columnCount) }

        return ([headers] + rows)
            .map { row in
                row
                    .map { plainDelimitedCell($0, separator: separator, quoteAll: quoteAll) }
                    .joined(separator: separator)
            }
            .joined(separator: "\n")
    }

    private static func tableRow(_ cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }

    private static func alignmentMarker(_ alignment: MarkdownTableAlignment) -> String {
        switch alignment {
        case .leading:
            return ":---"
        case .center:
            return ":---:"
        case .trailing:
            return "---:"
        }
    }

    private static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "|", with: "\\|")
    }

    private static func plainDelimitedCell(
        _ value: String,
        separator: String,
        quoteAll: Bool
    ) -> String {
        let plain = MarkdownPlainText.clean(value)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if separator == "\t" {
            return plain
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        }

        let escaped = plain.replacingOccurrences(of: "\"", with: "\"\"")
        let shouldQuote = quoteAll ||
            escaped.contains(separator) ||
            escaped.contains("\"") ||
            escaped.contains("\n")

        if shouldQuote {
            return "\"\(escaped)\""
        }

        return escaped
    }

    private static func normalized(_ values: [String], count: Int) -> [String] {
        normalized(values, count: count, fill: "")
    }

    private static func normalized<T>(_ values: [T], count: Int, fill: T) -> [T] {
        if values.count >= count {
            return Array(values.prefix(count))
        }

        return values + Array(repeating: fill, count: count - values.count)
    }
}
