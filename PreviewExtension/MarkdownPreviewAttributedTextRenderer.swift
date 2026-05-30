import AppKit
import MDQuickCopyCore

enum MarkdownPreviewAttributedTextRenderer {
    static func render(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            append(rawLine, to: result)

            if index < lines.index(before: lines.endIndex) {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private static func append(_ rawLine: String, to result: NSMutableAttributedString) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)

        if line.isEmpty {
            result.append(NSAttributedString(string: "\n"))
        } else if let heading = heading(line) {
            appendInline(
                heading.text,
                to: result,
                font: .systemFont(ofSize: headingSize(heading.level), weight: .semibold),
                color: .labelColor,
                paragraphSpacing: heading.level == 1 ? 8 : 3
            )
        } else if let task = taskListItem(line) {
            appendInline(
                "\(task.isDone ? "☑" : "☐") \(task.text)",
                to: result,
                font: .systemFont(ofSize: 13),
                color: .labelColor
            )
        } else if let unordered = unorderedListItem(line) {
            appendInline(
                "• \(unordered)",
                to: result,
                font: .systemFont(ofSize: 13),
                color: .labelColor
            )
        } else if let ordered = orderedListItem(line) {
            appendInline(
                "\(ordered.number). \(ordered.text)",
                to: result,
                font: .systemFont(ofSize: 13),
                color: .labelColor
            )
        } else if let quote = blockquote(line) {
            appendInline(
                "▏ \(quote)",
                to: result,
                font: .systemFont(ofSize: 13),
                color: .secondaryLabelColor
            )
        } else if isHorizontalRule(line) {
            result.append(styledPlainText(
                String(repeating: "─", count: 54),
                font: .systemFont(ofSize: 13),
                color: .separatorColor
            ))
        } else {
            appendInline(
                line,
                to: result,
                font: .systemFont(ofSize: 13),
                color: .labelColor
            )
        }
    }

    private static func appendInline(
        _ text: String,
        to result: NSMutableAttributedString,
        font: NSFont,
        color: NSColor,
        paragraphSpacing: CGFloat = 0
    ) {
        let attributed = NSMutableAttributedString(
            attributedString: NSAttributedString(MarkdownAttributedStringBuilder.build(text))
        )
        style(attributed, font: font, color: color, paragraphSpacing: paragraphSpacing)
        result.append(attributed)
    }

    private static func styledPlainText(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        style(attributed, font: font, color: color)
        return attributed
    }

    private static func style(
        _ attributed: NSMutableAttributedString,
        font: NSFont,
        color: NSColor,
        paragraphSpacing: CGFloat = 0
    ) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard fullRange.length > 0 else {
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = paragraphSpacing

        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        attributed.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let intent = inlinePresentationIntent(from: attributes[.inlinePresentationIntent])
            let isCode = intent.contains(.code)
            let isBold = intent.contains(.stronglyEmphasized)
            let isEmphasis = intent.contains(.emphasized)
            let isStrike = intent.contains(.strikethrough)
            let link = attributes[.link]

            let resolvedFont: NSFont
            if isCode {
                resolvedFont = .monospacedSystemFont(ofSize: max(font.pointSize - 1, 11), weight: .regular)
            } else {
                resolvedFont = font.withTraits(
                    isBold: isBold,
                    isItalic: isEmphasis
                )
            }

            attributed.addAttribute(.font, value: resolvedFont, range: range)
            attributed.addAttribute(.foregroundColor, value: link == nil ? color : NSColor.linkColor, range: range)

            if isStrike {
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }

            if link != nil {
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }

    private static func inlinePresentationIntent(from value: Any?) -> InlineIntent {
        let rawValue = if let number = value as? NSNumber {
            number.intValue
        } else if let value = value as? Int {
            value
        } else {
            0
        }

        return InlineIntent(rawValue: rawValue)
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }

        return (level, String(line.dropFirst(level + 1)))
    }

    private static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 30
        case 2: return 22
        case 3: return 18
        case 4: return 16
        default: return 15
        }
    }

    private static func unorderedListItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func taskListItem(_ line: String) -> (isDone: Bool, text: String)? {
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

    private static func orderedListItem(_ line: String) -> (number: String, text: String)? {
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

    private static func blockquote(_ line: String) -> String? {
        if line.hasPrefix("> ") {
            return String(line.dropFirst(2))
        }
        if line == ">" {
            return ""
        }
        return nil
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let collapsed = line.replacingOccurrences(of: " ", with: "")
        return collapsed.count >= 3 &&
            (collapsed.allSatisfy { $0 == "-" } ||
             collapsed.allSatisfy { $0 == "*" } ||
             collapsed.allSatisfy { $0 == "_" })
    }
}

private struct InlineIntent: OptionSet {
    let rawValue: Int

    static let emphasized = InlineIntent(rawValue: 1)
    static let stronglyEmphasized = InlineIntent(rawValue: 2)
    static let code = InlineIntent(rawValue: 4)
    static let strikethrough = InlineIntent(rawValue: 32)
}

private extension NSFont {
    func withTraits(isBold: Bool, isItalic: Bool) -> NSFont {
        var traits: NSFontTraitMask = []
        if isBold {
            traits.insert(.boldFontMask)
        }
        if isItalic {
            traits.insert(.italicFontMask)
        }

        guard !traits.isEmpty,
              let converted = NSFontManager.shared.convert(self, toHaveTrait: traits) as NSFont? else {
            return self
        }

        return converted
    }
}
