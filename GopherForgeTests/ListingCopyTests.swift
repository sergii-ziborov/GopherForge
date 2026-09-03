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

    /// The counts in the README are read by anyone deciding whether to look
    /// further, so they are worth the same check.
    func testTheReadmeQuotesTheRealCounts() throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let readme = try String(contentsOf: root.appending(path: "README.md"), encoding: .utf8)

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
