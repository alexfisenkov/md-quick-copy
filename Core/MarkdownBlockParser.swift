import Foundation

public enum MarkdownBlock: Equatable {
    case markdown(String)
    case code(language: String?, text: String)
}

public enum MarkdownBlockParser {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String?
        var isInsideCodeFence = false

        func flushMarkdown() {
            let text = markdownLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.markdown(text))
            }
            markdownLines.removeAll(keepingCapacity: true)
        }

        func flushCode() {
            blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
            codeLines.removeAll(keepingCapacity: true)
            codeLanguage = nil
        }

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") else {
                if isInsideCodeFence {
                    codeLines.append(line)
                } else {
                    markdownLines.append(line)
                }
                continue
            }

            if isInsideCodeFence {
                flushCode()
                isInsideCodeFence = false
            } else {
                flushMarkdown()
                isInsideCodeFence = true
                let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                codeLanguage = language.isEmpty ? nil : language
            }
        }

        if isInsideCodeFence {
            flushCode()
        } else {
            flushMarkdown()
        }

        return blocks
    }
}
