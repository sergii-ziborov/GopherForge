import XCTest
@testable import GopherForge

/// The App Store copy, checked against the thing it describes.
///
/// The submission document claimed forty lessons across seven units while the
/// app shipped forty-nine across nine. Nobody edits a release document when
/// they add a unit, so the document has to be checked rather than trusted —
/// and a reviewer comparing the listing, the screenshots and the app is
/// exactly who finds the difference.
///
/// The number checked is the one the Learn screen shows. This guard used to
/// compare against every lesson in the catalogue, challenges included, which
/// made both documents advertise 49 while the app's own progress card read
/// "0 of 29 lessons" — the guard was enforcing a mismatch rather than catching
/// one. Challenges are counted too, as what they are: Practice.
final class ListingCopyTests: XCTestCase {
    private func releaseDocument() throws -> String {
        // The tests run from the app bundle, so the document is read from the
        // source tree by walking up from this file.
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "docs/APP-STORE.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testTheDescriptionQuotesTheRealLessonAndUnitCount() throws {
        let document = try releaseDocument()
        let lessons = GoCourseCatalog.teachingLessons.count
        let units = GoCourseCatalog.units.count

        XCTAssertTrue(
            document.contains("\(lessons) lessons"),
            "the listing does not say \(lessons) lessons"
        )
        XCTAssertTrue(
            document.contains("nine units") || document.contains("\(units) units"),
            "the listing does not say \(units) units"
        )
        XCTAssertTrue(
            document.contains("\(GoCourseCatalog.challenges.count) question-and-answer challenges"),
            "the listing does not say how many challenges Practice holds"
        )
    }

    /// Every lesson count in the document has to be the real one.
    ///
    /// Checking that the right number appears somewhere is not enough, and the
    /// gap was not hypothetical: the promotional text advertised a 40-lesson
    /// course for weeks while the description below it said 49, and the test
    /// passed the whole time because it only ever asked whether the correct
    /// value was present. A stale number is not the absence of a fresh one.
    func testNoStaleLessonCountIsLeftAnywhere() throws {
        for (name, document) in try [
            ("docs/APP-STORE.md", releaseDocument()),
            ("README.md", readme()),
        ] {
            for quoted in Self.lessonCounts(in: document) {
                XCTAssertEqual(
                    quoted, GoCourseCatalog.teachingLessons.count,
                    "\(name) still says \(quoted) lessons"
                )
            }
        }
    }

    /// Every count that describes the whole course.
    ///
    /// Deliberately not every "N lessons" in the file: a screenshot's alt text
    /// says "0 of 4 lessons" about one unit, which is true and has nothing to
    /// do with the total. What matters is the phrasings that claim to describe
    /// the course — "a 29-lesson course", "29 lessons across nine units".
    private static func lessonCounts(in document: String) -> [Int] {
        let pattern = try? NSRegularExpression(pattern: "([0-9]+)[ -]lessons? (?:course|across)")
        let range = NSRange(document.startIndex..., in: document)
        return (pattern?.matches(in: document, range: range) ?? []).compactMap { match in
            guard let digits = Range(match.range(at: 1), in: document) else { return nil }
            return Int(document[digits])
        }
    }

    private func readme() throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: "README.md"), encoding: .utf8)
    }

    /// The counts in the README are read by anyone deciding whether to look
    /// further, so they are worth the same check.
    func testTheReadmeQuotesTheRealCounts() throws {
        let readme = try readme()

        XCTAssertTrue(
            readme.contains("\(GoCourseCatalog.teachingLessons.count) lessons"),
            "the README does not say \(GoCourseCatalog.teachingLessons.count) lessons"
        )
        XCTAssertTrue(
            readme.contains("\(GoCourseCatalog.challenges.count) question-and-answer challenges"),
            "the README does not say how many challenges Practice holds"
        )
    }
}
