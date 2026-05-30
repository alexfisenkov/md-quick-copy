import Foundation

public struct MarkdownOutlineItem: Equatable {
    public let level: Int
    public let title: String

    public init(level: Int, title: String) {
        self.level = level
        self.title = title
    }
}

public enum MarkdownOutlineBuilder {
    public static func build(from blocks: [MarkdownBlock]) -> [MarkdownOutlineItem] {
        blocks.flatMap { block -> [MarkdownOutlineItem] in
            guard case .markdown(let text) = block else {
                return []
            }

            return text
                .components(separatedBy: .newlines)
                .compactMap(outlineItem)
        }
    }

    private static func outlineItem(from rawLine: String) -> MarkdownOutlineItem? {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        let level = line.prefix { $0 == "#" }.count

        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }

        let rawTitle = String(line.dropFirst(level + 1))
        let title = MarkdownPlainText.clean(rawTitle)
        return title.isEmpty ? nil : MarkdownOutlineItem(level: level, title: title)
    }
}
