import XCTest
@testable import GopherForge

final class ExampleLibraryInvariantTests: XCTestCase {
    func testEveryExampleHasAUniqueIdentifierAndAGoFile() {
        let examples = GoExampleLibrary.all
        XCTAssertFalse(examples.isEmpty)
        XCTAssertEqual(Set(examples.map(\.id)).count, examples.count)
        for example in examples {
            XCTAssertFalse(example.source.isEmpty, example.id)
            XCTAssertFalse(example.title.isEmpty, example.id)
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
