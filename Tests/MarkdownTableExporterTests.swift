import XCTest
@testable import MDQuickCopyCore

final class MarkdownTableExporterTests: XCTestCase {
    func testExportsMarkdownWithColumnAlignment() throws {
        let table = MarkdownTable(
            headers: ["Provider", "WebSocket", "Risk"],
            alignments: [.leading, .center, .trailing],
            rows: [
                ["**Yandex Cloud**", "Yes", "KYC"],
                ["Gcore", "No", "Timeout"]
            ]
        )

        XCTAssertEqual(
            MarkdownTableExporter.markdown(table),
            """
            | Provider | WebSocket | Risk |
            | :--- | :---: | ---: |
            | **Yandex Cloud** | Yes | KYC |
            | Gcore | No | Timeout |
            """
        )
    }

    func testExportsCsvWithEscapedPlainTextCells() throws {
        let table = MarkdownTable(
            headers: ["Provider", "Risk"],
            alignments: [.leading, .leading],
            rows: [
                ["**Yandex Cloud**", "KYC, logs"],
                ["Gcore", #"Needs "manual" check"#]
            ]
        )

        XCTAssertEqual(
            MarkdownTableExporter.csv(table),
            """
            "Provider","Risk"
            "Yandex Cloud","KYC, logs"
            "Gcore","Needs ""manual"" check"
            """
        )
    }

    func testExportsTsvWithPlainTextCells() throws {
        let table = MarkdownTable(
            headers: ["Provider", "Risk"],
            alignments: [.leading, .leading],
            rows: [
                ["**Yandex Cloud**", "KYC, logs"],
                ["Gcore", "Timeout"]
            ]
        )

        XCTAssertEqual(
            MarkdownTableExporter.tsv(table),
            """
            Provider\tRisk
            Yandex Cloud\tKYC, logs
            Gcore\tTimeout
            """
        )
    }

    func testPlainTextExportsPreserveIdentifierUnderscores() throws {
        let table = MarkdownTable(
            headers: ["Key"],
            alignments: [.leading],
            rows: [
                ["`YOUR_REALITY_PUBLIC_KEY`"],
                ["safe_web_edge"],
                ["*emphasized*"]
            ]
        )

        XCTAssertEqual(
            MarkdownTableExporter.csv(table),
            """
            "Key"
            "YOUR_REALITY_PUBLIC_KEY"
            "safe_web_edge"
            "emphasized"
            """
        )
    }
}
