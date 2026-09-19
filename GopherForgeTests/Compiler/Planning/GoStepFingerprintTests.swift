import XCTest
@testable import GopherForge

final class GoStepFingerprintTests: XCTestCase {
    private func key(
        tag: String = "go1.24",
        language: String = "go1.24",
        path: String = "example.com/forge",
        sources: [String: String] = ["main.go": "package main\n"],
        deps: [String] = []
    ) -> String {
        GoStepFingerprint.key(
            toolchainTag: tag,
            languageVersion: language,
            packagePath: path,
            sources: sources,
            dependencyKeys: deps
        )
    }

    func testTheSameInputsProduceTheSameKey() {
        XCTAssertEqual(key(), key())
        XCTAssertEqual(key().count, 64)
        XCTAssertTrue(key().allSatisfy(\.isHexDigit))
    }

    func testEditingASourceChangesTheKey() {
        XCTAssertNotEqual(
            key(sources: ["main.go": "package main\n"]),
            key(sources: ["main.go": "package main\n\nfunc main() {}\n"])
        )
    }

    func testRenamingASourceChangesTheKey() {
        XCTAssertNotEqual(
            key(sources: ["a.go": "package p\n"]),
            key(sources: ["b.go": "package p\n"])
        )
    }

    func testAChangedDependencyKeyInvalidatesImporters() {
        XCTAssertNotEqual(
            key(deps: ["aaa"]),
            key(deps: ["bbb"])
        )
    }

    func testDependencyOrderDoesNotMatter() {
        XCTAssertEqual(
            key(deps: ["b", "a"]),
            key(deps: ["a", "b"])
        )
    }

    func testAToolchainBumpInvalidatesEveryArchive() {
        XCTAssertNotEqual(key(tag: "go1.24"), key(tag: "go1.25"))
    }

    func testALanguageBumpInvalidatesTheArchive() {
        XCTAssertNotEqual(key(language: "go1.23"), key(language: "go1.24"))
    }

    func testThePackagePathIsPartOfTheKey() {
        XCTAssertNotEqual(key(path: "a"), key(path: "a_test"))
    }
}
