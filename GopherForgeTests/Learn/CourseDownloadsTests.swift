import XCTest
import CryptoKit
@testable import GopherForge

final class CourseDownloadsTests: XCTestCase {
    private func fixture(_ id: String = "go") throws -> (CourseDownload, Data) {
        let descriptor = try XCTUnwrap(CourseLibrary.shared.catalog.first { $0.id == id })
        let url = try XCTUnwrap(Bundle.main.url(forResource: descriptor.fileName, withExtension: nil, subdirectory: "CourseFixtures"))
        return (descriptor, try Data(contentsOf: url))
    }
    func testExplicitFullInstallExportRemoveAndOfflineReinstall() throws {
        let (descriptor, data) = try fixture()
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(path: "Courses")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let progress = root.appending(path: "progress.json")
        try Data("retained learner evidence".utf8).write(to: progress)
        let library = CourseLibrary(directory: directory, catalog: [descriptor])
        XCTAssertTrue(library.packages.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "Opening the library must not install a course")
        try library.install(data, descriptor: descriptor)
        let reopened = CourseLibrary(directory: directory, catalog: [descriptor])
        let pack = try XCTUnwrap(reopened.packages.first)
        XCTAssertEqual(pack.units.flatMap(\.lessons).map(\.id), descriptor.lessonIDs)
        XCTAssertEqual(pack.solutions.count, 44)
        XCTAssertFalse(pack.practice.quizzes.isEmpty)
        XCTAssertFalse(pack.practice.drills.isEmpty)
        XCTAssertFalse(pack.practice.bugs.isEmpty)
        let exported = try reopened.export(descriptor)
        XCTAssertEqual(try Data(contentsOf: exported), data)
        try reopened.remove(descriptor)
        XCTAssertTrue(CourseLibrary(directory: directory, catalog: [descriptor]).packages.isEmpty)
        XCTAssertEqual(try String(contentsOf: progress, encoding: .utf8), "retained learner evidence")
        try reopened.install(Data(contentsOf: exported), descriptor: descriptor)
        XCTAssertEqual(reopened.packages.first?.revision, descriptor.revision)
    }
    func testTruncatedOrAlteredDownloadNeverReplacesGoodCourse() throws {
        let (descriptor, data) = try fixture("devops")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = CourseLibrary(directory: directory, catalog: [descriptor])
        try library.install(data, descriptor: descriptor)
        XCTAssertThrowsError(try library.install(data.dropLast(), descriptor: descriptor))
        var changed = data; changed[changed.startIndex] ^= 1
        XCTAssertThrowsError(try library.install(changed, descriptor: descriptor))
        XCTAssertEqual(try Data(contentsOf: library.export(descriptor)), data)
        XCTAssertEqual(library.packages.first?.labs.count, 6)
    }
    func testExportCannotPublishPartialOrMissingCourse() throws {
        let (descriptor, _) = try fixture()
        let library = CourseLibrary(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), catalog: [descriptor])
        XCTAssertThrowsError(try library.export(descriptor))
        XCTAssertEqual(library.knownLessonIDs, Set(descriptor.lessonIDs), "Progress identifiers survive content removal")
    }
    func testEveryOfficialPackIncludesItsCompleteReadingAndPracticeContent() throws {
        XCTAssertEqual(Set(CourseLibrary.shared.catalog.map(\.id)), ["go", "devops", "interview"])
        for descriptor in CourseLibrary.shared.catalog {
            let (_, data) = try fixture(descriptor.id)
            let pack = try CourseLibrary.validate(data, against: descriptor)
            XCTAssertEqual(pack.labs.count, descriptor.labCount)
            let lessonIDs = Set(pack.units.flatMap(\.lessons).map(\.id))
            XCTAssertTrue(pack.guides.allSatisfy { lessonIDs.contains($0.id) })
            XCTAssertTrue(pack.hints.allSatisfy { lessonIDs.contains($0.id) })
            XCTAssertTrue(Set(pack.solutions.keys).isSubset(of: lessonIDs))
            if let bank = pack.interview { XCTAssertEqual(bank.questions.count, 132); XCTAssertEqual(bank.demonstrations.count, 12) }
        }
    }

    func testNewCatalogPreservesInstalledOfflineRevisionUntilExplicitUpdate() throws {
        let (old, original) = try fixture()
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let initial = CourseLibrary(directory: directory, catalog: [old])
        try initial.install(original, descriptor: old)
        var package = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        package["revision"] = "2026-11-08.1"
        let updated = try JSONSerialization.data(withJSONObject: package, options: [.sortedKeys])
        var metadata = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        metadata["revision"] = "2026-11-08.1"
        metadata["fileName"] = "go-2026-11-08.1.gfcourse.json"
        metadata["byteCount"] = updated.count
        metadata["sha256"] = SHA256.hash(data: updated).map { String(format: "%02x", $0) }.joined()
        let next = try JSONDecoder().decode(CourseDownload.self, from: JSONSerialization.data(withJSONObject: metadata))
        let upgraded = CourseLibrary(directory: directory, catalog: [next])
        XCTAssertEqual(upgraded.packages.first?.revision, old.revision)
        XCTAssertEqual(try Data(contentsOf: upgraded.export(next)), original)
        try upgraded.install(updated, descriptor: next)
        XCTAssertEqual(CourseLibrary(directory: directory, catalog: [next]).packages.first?.revision, next.revision)
        XCTAssertEqual(try Data(contentsOf: upgraded.export(next)), updated)
    }

    @MainActor func testProgressExportRetainsMarksWhenAllCourseContentIsUnloaded() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = CourseLibrary(directory: directory.appending(path: "Courses"), catalog: CourseLibrary.shared.catalog)
        XCTAssertTrue(library.packages.isEmpty)
        let lessonID = try XCTUnwrap(library.knownLessonIDs.sorted().first)
        let interviewID = try XCTUnwrap(library.knownInterviewIDs.sorted().first)
        let store = LearningProgressStore(storageURL: directory.appending(path: "progress.json"))
        try await store.record(LessonAttempt(lessonID: lessonID, succeeded: true, mistakeTags: [], compileAttempts: 0, compilerVerified: false))
        let suite = "CourseDownloadsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(String(decoding: try JSONEncoder().encode([interviewID: "understood"]), as: UTF8.self), forKey: "interview.preparation.selfAssessment.v1")
        defaults.set(lessonID, forKey: "learning.lastLesson.v1")
        defaults.set(interviewID, forKey: "learning.lastInterview.v1")
        let snapshot = try await LearningShareSnapshot.make(store: store, defaults: defaults, library: library)
        XCTAssertEqual(snapshot.completed, [lessonID])
        XCTAssertEqual(snapshot.assessments, [interviewID: "understood"])
        XCTAssertEqual(snapshot.lastLessonID, lessonID)
        XCTAssertEqual(snapshot.lastInterviewID, interviewID)
        XCTAssertTrue(library.packages.isEmpty)
    }
}
