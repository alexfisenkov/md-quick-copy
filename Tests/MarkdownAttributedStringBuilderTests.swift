import XCTest
@testable import MDQuickCopyCore

final class MarkdownAttributedStringBuilderTests: XCTestCase {
    func testBuildsMarkdownLinksWithURLAttributes() throws {
        let attributed = MarkdownAttributedStringBuilder.build(
            "Source: [Yandex Cloud](https://yandex.cloud/en/docs/api-gateway/concepts/extensions/websocket)"
        )

        XCTAssertEqual(
            links(in: attributed),
            [
                "Yandex Cloud": "https://yandex.cloud/en/docs/api-gateway/concepts/extensions/websocket"
            ]
        )
    }

    func testBuildsBareURLLinksWithURLAttributes() throws {
        let attributed = MarkdownAttributedStringBuilder.build(
            "Open https://ntc.party/t/domain-borrowing/2972 for details."
        )

        XCTAssertEqual(
            links(in: attributed),
            [
                "https://ntc.party/t/domain-borrowing/2972": "https://ntc.party/t/domain-borrowing/2972"
            ]
        )
    }

    func testPreservesListPrefixesWhileParsingInlineMarkdown() throws {
        let attributed = MarkdownAttributedStringBuilder.build(
            "1. Open [docs](https://example.com/docs)"
        )

        XCTAssertEqual(String(attributed.characters), "1. Open docs")
        XCTAssertEqual(
            links(in: attributed),
            [
                "docs": "https://example.com/docs"
            ]
        )
    }

    private func links(in attributed: AttributedString) -> [String: String] {
        var result: [String: String] = [:]

        for run in attributed.runs {
            guard let url = run.link else {
                continue
            }

            let text = String(attributed.characters[run.range])
            result[text] = url.absoluteString
        }

        return result
    }
}
