import XCTest
@testable import GopherForge

final class ProjectPathNormalizerTests: XCTestCase {
    func testAGuestWorkPathBecomesProjectRelative() {
        XCTAssertEqual(
            ProjectPathNormalizer.normalize("/tmp/job/work/main.go"),
            "main.go"
        )
        XCTAssertEqual(
            ProjectPathNormalizer.normalize("/work/internal/greet/greet.go"),
            "internal/greet/greet.go"
        )
    }

    func testADotSlashPrefixIsStripped() {
        XCTAssertEqual(ProjectPathNormalizer.normalize("./main.go"), "main.go")
        XCTAssertEqual(ProjectPathNormalizer.normalize("././cmd/one/main.go"), "cmd/one/main.go")
    }

    func testBackslashesBecomeSlashes() {
        XCTAssertEqual(ProjectPathNormalizer.normalize("cmd\\one\\main.go"), "cmd/one/main.go")
    }

    func testABareNameIsUnchanged() {
        XCTAssertEqual(ProjectPathNormalizer.normalize("main.go"), "main.go")
    }
}
