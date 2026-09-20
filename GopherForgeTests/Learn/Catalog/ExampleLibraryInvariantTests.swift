import XCTest
@testable import GopherForge

final class ExampleLibraryInvariantTests: XCTestCase {
    private let standardLibrary: Set<String> = [
        "bufio", "cmp", "context", "embed", "encoding/json", "errors", "fmt",
        "image", "image/color", "image/png", "io", "math", "math/rand",
        "net/http", "net/http/httptest", "os", "slices", "sort", "strings",
        "sync", "testing", "time", "unsafe",
    ]

    func testEveryExampleHasAUniqueIdentifierAndAGoFile() {
        let examples = GoExampleLibrary.all
        XCTAssertFalse(examples.isEmpty)
        XCTAssertEqual(Set(examples.map(\.id)).count, examples.count)
        for example in examples {
            XCTAssertFalse(example.source.isEmpty, example.id)
            XCTAssertFalse(example.title.isEmpty, example.id)
            XCTAssertFalse(example.expectedOutput.isEmpty, example.id)
            XCTAssertTrue(example.expectedOutput.hasSuffix("\n"), example.id)
            XCTAssertTrue(example.source.contains("package "), example.id)
        }
    }

    func testTheHomeLibraryListsSitesAndGraphics() {
        let titles = GoExampleLibrary.sections.map(\.title)
        XCTAssertEqual(titles.first, "Sites")
        XCTAssertTrue(titles.contains("Graphics"))
        XCTAssertGreaterThanOrEqual(GoExampleLibrarySites.all.count, 3)
        XCTAssertGreaterThanOrEqual(
            GoExampleLibraryGraphics.all.count + GoExampleLibraryGraphicsMore.all.count,
            7
        )
        XCTAssertEqual(ProjectHomeLimits.recentCount, 5)
    }

    func testEverySiteExampleIsAGinProjectWithPagesAndScripts() {
        XCTAssertEqual(GoExampleLibrarySites.all.map(\.id), ["site.cafe", "site.notes", "site.shop"])
        for example in GoExampleLibrarySites.all {
            XCTAssertTrue(example.servesSite, example.id)
            XCTAssertTrue(example.source.contains("github.com/gin-gonic/gin"), example.id)
            XCTAssertTrue(example.source.contains("gin.Default()"), example.id)
            XCTAssertNotNil(example.extraFiles["web/index.html"], example.id)
            XCTAssertNotNil(example.extraFiles["web/styles.css"], example.id)
            XCTAssertNotNil(example.extraFiles["web/app.js"], example.id)
            XCTAssertTrue(
                example.extraFiles.keys.contains { $0.hasPrefix("vendor/github.com/gin-gonic/gin/") },
                example.id
            )
            XCTAssertTrue(example.expectedOutput.contains("Checking Gin routes"), example.id)
            XCTAssertTrue(example.files.keys.contains("go.mod"), example.id)
            XCTAssertTrue(example.files["go.mod"]?.contains("github.com/gin-gonic/gin") == true, example.id)
        }
    }

    func testEveryGraphicExampleClaimsAnImage() {
        let graphics = GoExampleLibraryGraphics.all + GoExampleLibraryGraphicsMore.all
        XCTAssertFalse(graphics.isEmpty)
        for example in graphics {
            XCTAssertTrue(example.producesImage, example.id)
            XCTAssertTrue(example.source.contains("image/png"), example.id)
            XCTAssertTrue(example.source.contains("/sandbox/"), example.id)
        }
    }

    func testEveryExampleResolvesAsAPackageGraph() throws {
        for example in GoExampleLibrary.all {
            let files = example.files
            if example.vendoredModule != nil {
                continue
            }
            let module = GoModParser.parse(files["go.mod"] ?? "")?.modulePath
                ?? example.modulePath
            XCTAssertNoThrow(
                try GoPackageGraph.build(
                    files: files,
                    modulePath: module,
                    standardLibrary: standardLibrary
                ),
                example.id
            )
        }
    }

    func testSitePagesHighlightAsWebFiles() {
        for example in GoExampleLibrarySites.all {
            for (path, text) in example.extraFiles where !path.hasPrefix("vendor/") {
                let kind = SourceFileKind.of(path: path)
                if kind == .html || kind == .javascript || kind == .css || kind == .json {
                    XCTAssertFalse(kind.tokens(in: text).isEmpty, "\(example.id) \(path)")
                }
            }
        }
    }

    func testTeachingLessonsAreASubsetOfTheCatalogue() {
        let all = Set(GoCourseCatalog.lessons.map(\.id))
        let teaching = Set(GoCourseCatalog.teachingLessons.map(\.id))
        XCTAssertTrue(teaching.isSubset(of: all))
        XCTAssertLessThanOrEqual(GoCourseCatalog.teachingLessons.count, GoCourseCatalog.lessons.count)
        XCTAssertFalse(GoCourseCatalog.units.isEmpty)
        XCTAssertFalse(GoCourseCatalog.challenges.isEmpty)
    }
}
