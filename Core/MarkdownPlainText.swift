import Foundation

enum MarkdownPlainText {
    static func clean(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br />", with: " ")

        cleaned = replacing(pattern: #"!\[([^\]]*)\]\([^)]+\)"#, in: cleaned, with: "$1")
        cleaned = replacing(pattern: #"\[([^\]]+)\]\([^)]+\)"#, in: cleaned, with: "$1")

        for marker in ["**", "__", "~~", "`"] {
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        cleaned = replacing(pattern: #"(?<!\w)\*([^*]+)\*(?!\w)"#, in: cleaned, with: "$1")
        cleaned = replacing(pattern: #"(?<!\w)_([^_]+)_(?!\w)"#, in: cleaned, with: "$1")

        let escapedCharacters = [
            "\\|": "|",
            "\\_": "_",
            "\\*": "*",
            "\\`": "`",
            "\\[": "[",
            "\\]": "]",
            "\\(": "(",
            "\\)": ")",
            "\\#": "#",
            "\\+": "+",
            "\\-": "-",
            "\\.": "."
        ]

        for (escaped, replacement) in escapedCharacters {
            cleaned = cleaned.replacingOccurrences(of: escaped, with: replacement)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacing(pattern: String, in text: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: template
        )
    }
}
