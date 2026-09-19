import XCTest
@testable import GopherForge

final class GoLanguageTests: XCTestCase {
    func testAGeneratedModuleAsksForTheDeclaredVersion() {
        let source = GoLanguage.module("example.com/forge")
        XCTAssertTrue(source.contains("module example.com/forge"))
        XCTAssertTrue(source.contains("go \(GoLanguage.declaredModuleVersion)"))
        XCTAssertEqual(GoLanguage.declaredModuleVersion, "1.24")
    }

    func testTheModuleFileEndsWithANewline() {
        XCTAssertTrue(GoLanguage.module("playground").hasSuffix("\n"))
    }
}
