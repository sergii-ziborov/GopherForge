import XCTest
@testable import GopherForge

final class GoImportConfigurationTests: XCTestCase {
    func testEntriesAreSortedAndTerminated() {
        let rendered = GoImportConfiguration.render([
            "fmt": "/goroot/pkg/fmt.a",
            "example.com/forge": "/tmp/forge.a",
        ])
        XCTAssertTrue(rendered.hasSuffix("\n"))
        let lines = rendered.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "packagefile example.com/forge=/tmp/forge.a")
        XCTAssertEqual(lines.last, "packagefile fmt=/goroot/pkg/fmt.a")
    }

    func testAnEmptyMapIsASingleNewline() {
        XCTAssertEqual(GoImportConfiguration.render([:]), "\n")
    }
}
