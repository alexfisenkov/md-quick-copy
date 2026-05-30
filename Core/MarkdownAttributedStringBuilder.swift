import Foundation

public enum MarkdownAttributedStringBuilder {
    public static func build(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}
