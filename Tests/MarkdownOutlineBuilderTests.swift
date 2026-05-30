import XCTest
@testable import MDQuickCopyCore

final class MarkdownOutlineBuilderTests: XCTestCase {
    func testBuildsOutlineFromMarkdownBlocksOnly() throws {
        let blocks = MarkdownBlockParser.parse("""
        # **VPN через CDN**

        Intro

        ```bash
        # This is code, not a heading
        echo ok
        ```

        ## Таблица провайдеров

        | Provider | Risk |
        | --- | --- |
        | Gcore | Timeout |

        ### `Reality` notes
        """)

        XCTAssertEqual(
            MarkdownOutlineBuilder.build(from: blocks),
            [
                MarkdownOutlineItem(level: 1, title: "VPN через CDN"),
                MarkdownOutlineItem(level: 2, title: "Таблица провайдеров"),
                MarkdownOutlineItem(level: 3, title: "Reality notes")
            ]
        )
    }

    func testIgnoresInvalidHeadingLikeText() throws {
        let blocks: [MarkdownBlock] = [
            .markdown("""
            #Valid without required space
            ####### Too deep
            ### Good heading
            """)
        ]

        XCTAssertEqual(
            MarkdownOutlineBuilder.build(from: blocks),
            [
                MarkdownOutlineItem(level: 3, title: "Good heading")
            ]
        )
    }
}
