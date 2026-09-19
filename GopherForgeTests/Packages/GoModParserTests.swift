import XCTest
@testable import GopherForge

final class GoModParserTests: XCTestCase {
    func testParsesBlockAndSingleLineDirectives() {
        let source = """
        module example.com/forge

        go 1.27

        require (
        \tgithub.com/pkg/errors v0.9.1
        \tgolang.org/x/text v0.14.0 // indirect
        )

        require example.com/single v1.2.3

        replace example.com/old => ./local
        """
        let module = GoModParser.parse(source)

        XCTAssertEqual(module?.modulePath, "example.com/forge")
        XCTAssertEqual(module?.goVersion, "1.27")
        XCTAssertEqual(module?.requirements.count, 3)
        XCTAssertEqual(module?.directRequirements.count, 2)
        XCTAssertEqual(module?.replacements.first?.isLocal, true)
    }

    func testIndirectMarkerIsRead() {
        let module = GoModParser.parse("""
        module m

        require golang.org/x/text v0.14.0 // indirect
        """)
        XCTAssertEqual(module?.requirements.first?.isIndirect, true)
    }

    func testMissingModuleLineIsRejected() {
        XCTAssertNil(GoModParser.parse("go 1.27\n"))
    }

    func testRenderRoundTrips() {
        let source = "module example.com/forge\n\ngo 1.27\n"
        let module = GoModParser.parse(source)
        let rendered = module?.rendered()
        XCTAssertEqual(GoModParser.parse(rendered ?? "")?.modulePath, "example.com/forge")
    }

    func testSelfContainedRequiresLocalReplacements() {
        let module = GoModParser.parse("""
        module m

        require example.com/dep v1.0.0
        """)
        XCTAssertEqual(module?.isSelfContained, false)
    }
}
