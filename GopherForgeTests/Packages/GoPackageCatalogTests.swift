import XCTest
@testable import GopherForge

final class GoPackageCatalogTests: XCTestCase {
    func testEveryEntryHasAPathAndACategory() {
        XCTAssertFalse(GoPackageCatalog.entries.isEmpty)
        XCTAssertEqual(Set(GoPackageCatalog.entries.map(\.path)).count, GoPackageCatalog.entries.count)
        for entry in GoPackageCatalog.entries {
            XCTAssertFalse(entry.blurb.isEmpty)
            XCTAssertFalse(entry.category.isEmpty)
            XCTAssertEqual(entry.id, entry.path)
        }
        XCTAssertEqual(
            GoPackageCatalog.categories,
            ["Identifiers", "Testing", "Command line", "Errors", "Encoding", "HTTP", "Concurrency", "Text"]
        )
    }

    func testFilteringIsALocalSubstring() {
        XCTAssertEqual(GoPackageCatalog.filtered(by: "  ").count, GoPackageCatalog.entries.count)
        XCTAssertTrue(GoPackageCatalog.filtered(by: "uuid").contains { $0.path.contains("uuid") })
        XCTAssertTrue(GoPackageCatalog.filtered(by: "HTTP").allSatisfy { $0.category == "HTTP" || $0.blurb.lowercased().contains("http") || $0.path.lowercased().contains("http") })
        XCTAssertTrue(GoPackageCatalog.filtered(by: "no-such-module").isEmpty)
        XCTAssertEqual(GoPackageCatalog.entries(in: "Testing").count, 2)
    }

    func testATypedPathLooksLikeAModule() {
        XCTAssertTrue(GoPackageCatalog.looksLikeModulePath("github.com/google/uuid"))
        XCTAssertTrue(GoPackageCatalog.looksLikeModulePath("gopkg.in/yaml.v3"))
        XCTAssertFalse(GoPackageCatalog.looksLikeModulePath("uuid"))
        XCTAssertFalse(GoPackageCatalog.looksLikeModulePath("github.com google uuid"))
        XCTAssertFalse(GoPackageCatalog.looksLikeModulePath(""))
    }
}
