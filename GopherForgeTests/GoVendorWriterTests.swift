import XCTest
@testable import GopherForge

/// What an install actually does to a project.
///
/// The writer is pure — files in, files out — so the whole effect of installing
/// a package is something a test can state exactly.
final class GoVendorWriterTests: XCTestCase {
    private let reference = GoModuleReference(path: "github.com/google/uuid", version: "v1.6.0")

    private var project: [String: String] {
        [
            "go.mod": "module playground\n\ngo 1.24\n",
            "main.go": "package main\n\nfunc main() {}\n",
        ]
    }

    private func install(
        _ files: [String: String],
        vendored: [String: String] = ["uuid.go": "package uuid\n"]
    ) -> [String: String] {
        GoVendorWriter.apply(
            installation: .init(reference: reference, packages: [reference.path]),
            vendoredFiles: vendored,
            goSumLines: "github.com/google/uuid v1.6.0 h1:AAA=\n"
                + "github.com/google/uuid v1.6.0/go.mod h1:BBB=\n",
            to: files
        )
    }

    func testTheModuleLandsUnderVendorWithItsOwnImportPath() {
        let result = install(project)

        XCTAssertEqual(result["vendor/github.com/google/uuid/uuid.go"], "package uuid\n")
        XCTAssertEqual(result["main.go"], project["main.go"], "other files are untouched")
    }

    func testGoModGainsExactlyOneRequireLine() {
        let result = install(project)
        let requires = (result["go.mod"] ?? "")
            .components(separatedBy: "\n")
            .compactMap(GoVendorWriter.requireLineModulePath)

        XCTAssertEqual(requires, ["github.com/google/uuid"])
        XCTAssertTrue(result["go.mod"]?.contains("v1.6.0") == true)
    }

    /// Installing a different version of something already required must
    /// replace the line, not add a second one for the same module.
    func testReinstallingADifferentVersionReplacesTheRequirement() {
        var files = project
        files["go.mod"] = "module playground\n\ngo 1.24\n\nrequire (\n\tgithub.com/google/uuid v1.1.0\n)\n"

        let result = install(files)
        let requires = (result["go.mod"] ?? "")
            .components(separatedBy: "\n")
            .compactMap(GoVendorWriter.requireLineModulePath)

        XCTAssertEqual(requires, ["github.com/google/uuid"])
        XCTAssertFalse(result["go.mod"]?.contains("v1.1.0") == true)
        XCTAssertTrue(result["go.mod"]?.contains("v1.6.0") == true)
    }

    /// A version bump must not leave the previous version's files behind: a
    /// removed file would keep compiling against the new one.
    func testReinstallingRemovesTheOldFiles() {
        var files = install(project, vendored: ["old.go": "package uuid\n", "uuid.go": "package uuid\n"])
        XCTAssertNotNil(files["vendor/github.com/google/uuid/old.go"])

        files = install(files, vendored: ["uuid.go": "package uuid\n"])

        XCTAssertNil(files["vendor/github.com/google/uuid/old.go"])
        XCTAssertNotNil(files["vendor/github.com/google/uuid/uuid.go"])
    }

    func testGoSumIsSortedAndNeverDuplicated() {
        let once = install(project)
        let twice = install(once)

        XCTAssertEqual(once["go.sum"], twice["go.sum"], "installing twice should be idempotent")
        let lines = (twice["go.sum"] ?? "").components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(Set(lines).count, lines.count)
        XCTAssertEqual(lines, lines.sorted())
    }

    func testModulesTextListsTheVendoredPackages() {
        let result = install(project, vendored: [
            "uuid.go": "package uuid\n",
            "internal/x/x.go": "package x\n",
        ])
        let text = result["vendor/modules.txt"] ?? ""

        XCTAssertTrue(text.contains("# github.com/google/uuid v1.6.0"))
        XCTAssertTrue(text.contains("github.com/google/uuid\n"))
        XCTAssertTrue(text.contains("github.com/google/uuid/internal/x"))
    }

    // MARK: - What gets vendored

    /// `go mod vendor` drops tests and testdata, and on a phone that is most of
    /// the download.
    func testTestsAndHiddenFilesAreNotVendored() {
        XCTAssertTrue(GoModuleArchive.isVendored("uuid.go"))
        XCTAssertTrue(GoModuleArchive.isVendored("go.mod"))
        XCTAssertTrue(GoModuleArchive.isVendored("LICENSE"))
        XCTAssertFalse(GoModuleArchive.isVendored("uuid_test.go"))
        XCTAssertFalse(GoModuleArchive.isVendored("testdata/golden.txt"))
        XCTAssertFalse(GoModuleArchive.isVendored(".github/workflows/ci.yml"))
        XCTAssertFalse(GoModuleArchive.isVendored("README.md"))
    }

    /// An archive entry outside the module's own prefix is how a zip escapes
    /// the directory it is unpacked into.
    func testAnEntryOutsideTheModuleIsRefused() {
        let prefix = "github.com/google/uuid@v1.6.0/"
        XCTAssertTrue(GoModuleArchive.isSafe(prefix + "uuid.go", under: prefix))
        XCTAssertFalse(GoModuleArchive.isSafe("../../etc/passwd", under: prefix))
        XCTAssertFalse(GoModuleArchive.isSafe(prefix + "../escape.go", under: prefix))
        XCTAssertFalse(GoModuleArchive.isSafe("other@v1.0.0/uuid.go", under: prefix))
    }

    func testPackagesAreNamedFromTheModuleRoot() {
        XCTAssertEqual(
            GoPackageInstaller.packages(
                in: ["uuid.go": "", "internal/x/x.go": "", "LICENSE": ""],
                modulePath: "github.com/google/uuid"
            ),
            ["github.com/google/uuid", "github.com/google/uuid/internal/x"]
        )
    }
}
