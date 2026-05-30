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

    func testParserSupportsTildeFencedCodeBlocks() throws {
        let blocks = MarkdownBlockParser.parse("""
        ~~~toml
        enabled = true
        ~~~
        """)

        XCTAssertEqual(blocks, [
            .code(language: "toml", text: "enabled = true")
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

    func testParserDetectsGitHubStyleTables() throws {
        let blocks = MarkdownBlockParser.parse("""
        Before

        | Provider | WebSocket | Risk |
        | :---- | :----: | ----: |
        | **Yandex Cloud** | Yes | KYC |
        | Gcore | No | Timeout |

        After
        """)

        XCTAssertEqual(blocks, [
            .markdown("Before"),
            .table(MarkdownTable(
                headers: ["Provider", "WebSocket", "Risk"],
                alignments: [.leading, .center, .trailing],
                rows: [
                    ["**Yandex Cloud**", "Yes", "KYC"],
                    ["Gcore", "No", "Timeout"]
                ]
            )),
            .markdown("After")
        ])
    }

    func testParserDetectsExportedLanguageLabelCodeBlocks() throws {
        let blocks = MarkdownBlockParser.parse("""
        Config:

        JSON  
        {  
          "serverName": "vkvideo.ru",  
          "publicKey": "YOUR\\_REALITY\\_PUBLIC\\_KEY"  
        }

        ### Next section
        """)

        XCTAssertEqual(blocks, [
            .markdown("Config:"),
            .code(
                language: "JSON",
                text: """
                {
                  "serverName": "vkvideo.ru",
                  "publicKey": "YOUR_REALITY_PUBLIC_KEY"
                }
                """
            ),
            .markdown("### Next section")
        ])
    }

    func testParserDetectsIndentedCodeBlocks() throws {
        let blocks = MarkdownBlockParser.parse("""
        Before

            curl -I https://example.com
            echo ok

        After
        """)

        XCTAssertEqual(blocks, [
            .markdown("Before"),
            .code(language: nil, text: "curl -I https://example.com\necho ok"),
            .markdown("After")
        ])
    }
}
