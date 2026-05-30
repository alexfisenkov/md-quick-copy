import XCTest
@testable import MDQuickCopyCore

final class MarkdownBlockParserTests: XCTestCase {
    func testParserSplitsMarkdownAndFencedCodeBlocks() throws {
        let blocks = MarkdownBlockParser.parse("""
        # Demo

        ```bash
        echo "hello"
        ```

        After
        """)

        XCTAssertEqual(blocks, [
            .markdown("# Demo"),
            .code(language: "bash", text: "echo \"hello\""),
            .markdown("After")
        ])
    }

    func testParserKeepsCodeBlockWithoutLanguage() throws {
        let blocks = MarkdownBlockParser.parse("""
        Before

        ```
        line 1
        line 2
        ```
        """)

        XCTAssertEqual(blocks, [
            .markdown("Before"),
            .code(language: nil, text: "line 1\nline 2")
        ])
    }

    func testParserTreatsUnclosedFenceAsCodeBlock() throws {
        let blocks = MarkdownBlockParser.parse("""
        Intro

        ```json
        {"ok": true}
        """)

        XCTAssertEqual(blocks, [
            .markdown("Intro"),
            .code(language: "json", text: #"{"ok": true}"#)
        ])
    }
}
