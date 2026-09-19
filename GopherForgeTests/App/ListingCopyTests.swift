import XCTest
@testable import GopherForge

/// The public README, checked against the course it describes.
///
/// A count that drifts in the README is what a visitor sees first. The number
/// checked is the one the Learn screen shows. Challenges are counted too, as
/// what they are: Practice.
final class ListingCopyTests: XCTestCase {
    private func readme() throws -> String {
        let root = try TestRepoRoot.url()
        return try String(contentsOf: root.appending(path: "README.md"), encoding: .utf8)
    }

    func testTheReadmeQuotesTheRealCounts() throws {
        let readme = try readme()
        let lessons = GoCourseCatalog.teachingLessons.count

        XCTAssertTrue(
            readme.contains("\(lessons) lessons"),
            "the README does not say \(lessons) lessons"
        )
        XCTAssertTrue(
            readme.contains("\(GoCourseCatalog.challenges.count) question-and-answer challenges"),
            "the README does not say how many challenges Practice holds"
        )
    }

    /// Every lesson count that describes the whole course has to be the real
    /// one. Screenshot alt text such as "0 of 4 lessons" is a unit, not the
    /// total, and is ignored.
    func testNoStaleLessonCountIsLeftAnywhere() throws {
        let document = try readme()
        for quoted in Self.lessonCounts(in: document) {
            XCTAssertEqual(
                quoted, GoCourseCatalog.teachingLessons.count,
                "README.md still says \(quoted) lessons"
            )
        }
    }

    private static func lessonCounts(in document: String) -> [Int] {
        let pattern = try? NSRegularExpression(pattern: "([0-9]+)[ -]lessons? (?:course|across)")
        let range = NSRange(document.startIndex..., in: document)
        return (pattern?.matches(in: document, range: range) ?? []).compactMap { match in
            guard let digits = Range(match.range(at: 1), in: document) else { return nil }
            return Int(document[digits])
        }
    }
}
