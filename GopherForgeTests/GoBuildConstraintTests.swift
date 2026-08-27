import XCTest
@testable import GopherForge

/// Which files are in the build.
///
/// This is not a nicety. A package with two mutually exclusive implementations
/// — the `debug_enable.go` / `debug_disable.go` pair that half the ecosystem
/// ships — compiles both without it, and every symbol in it is declared twice.
final class GoBuildConstraintTests: XCTestCase {
    private let constraint = GoBuildConstraint(
        environment: .wasip1(goVersion: "go1.24.2")
    )

    // MARK: - File names

    func testAFileNamedForAnotherPlatformIsExcluded() {
        XCTAssertFalse(constraint.matchesFileName("net_linux.go"))
        XCTAssertFalse(constraint.matchesFileName("net_windows.go"))
        XCTAssertFalse(constraint.matchesFileName("cpu_amd64.go"))
        XCTAssertFalse(constraint.matchesFileName("sys_linux_amd64.go"))
    }

    func testAFileNamedForThisPlatformIsIncluded() {
        XCTAssertTrue(constraint.matchesFileName("net_wasip1.go"))
        XCTAssertTrue(constraint.matchesFileName("cpu_wasm.go"))
        XCTAssertTrue(constraint.matchesFileName("sys_wasip1_wasm.go"))
    }

    /// A suffix that is not a platform is just part of the name.
    func testAnOrdinarySuffixIsNotAConstraint() {
        XCTAssertTrue(constraint.matchesFileName("report_slices.go"))
        XCTAssertTrue(constraint.matchesFileName("debug_disable.go"))
        XCTAssertTrue(constraint.matchesFileName("main.go"))
        XCTAssertTrue(constraint.matchesFileName("cmp/internal/value/pointer.go"))
    }

    func testTheTestSuffixIsStrippedBeforeTheCheck() {
        XCTAssertFalse(constraint.matchesFileName("net_linux_test.go"))
        XCTAssertTrue(constraint.matchesFileName("net_wasip1_test.go"))
    }

    // MARK: - Build lines

    func testAGoBuildLineDecides() {
        XCTAssertTrue(includes("//go:build wasip1\n\npackage x\n"))
        XCTAssertFalse(includes("//go:build linux\n\npackage x\n"))
        XCTAssertTrue(includes("//go:build !linux\n\npackage x\n"))
        XCTAssertFalse(includes("//go:build ignore\n\npackage x\n"))
    }

    /// The pair that started this: one is in, the other is out, and which is
    /// which depends only on the tag.
    func testTheDebugPairResolvesToExactlyOneFile() {
        let enabled = "//go:build cmp_debug\n\npackage diff\n"
        let disabled = "//go:build !cmp_debug\n\npackage diff\n"

        XCTAssertFalse(includes(enabled))
        XCTAssertTrue(includes(disabled))
    }

    func testExpressionsCombine() {
        XCTAssertTrue(includes("//go:build wasm && !linux\n\npackage x\n"))
        XCTAssertFalse(includes("//go:build wasm && linux\n\npackage x\n"))
        XCTAssertTrue(includes("//go:build linux || wasip1\n\npackage x\n"))
        XCTAssertTrue(includes("//go:build (linux || wasip1) && !cgo\n\npackage x\n"))
        XCTAssertFalse(includes("//go:build (linux || darwin) && wasm\n\npackage x\n"))
    }

    /// Go treats every release up to the current one as satisfied.
    func testReleaseTagsAreSatisfiedUpToTheBundledVersion() {
        XCTAssertTrue(includes("//go:build go1.21\n\npackage x\n"))
        XCTAssertTrue(includes("//go:build go1.24\n\npackage x\n"))
        XCTAssertFalse(includes("//go:build go1.30\n\npackage x\n"))
    }

    /// Modules published before Go 1.17 still use the old form, and they are
    /// still on the proxy.
    func testTheLegacyPlusBuildFormIsUnderstood() {
        XCTAssertTrue(includes("// +build wasip1\n\npackage x\n"))
        XCTAssertFalse(includes("// +build linux\n\npackage x\n"))
        // Space is OR within a line.
        XCTAssertTrue(includes("// +build linux wasip1\n\npackage x\n"))
        // Comma is AND.
        XCTAssertFalse(includes("// +build linux,wasip1\n\npackage x\n"))
        // Separate lines are ANDed.
        XCTAssertFalse(includes("// +build wasip1\n// +build linux\n\npackage x\n"))
    }

    func testTheModernFormWinsWhenBothArePresent() {
        let source = "//go:build wasip1\n// +build linux\n\npackage x\n"
        XCTAssertTrue(includes(source))
    }

    /// Only the header counts: both forms must precede the package clause, so
    /// a comment further down cannot change the answer.
    func testALineAfterThePackageClauseIsIgnored() {
        XCTAssertTrue(includes("package x\n\n//go:build linux\n"))
    }

    func testAFileWithNoConstraintIsIncluded() {
        XCTAssertTrue(includes("package x\n\nfunc F() {}\n"))
    }

    private func includes(_ source: String, path: String = "file.go") -> Bool {
        constraint.includes(path: path, source: source)
    }
}
