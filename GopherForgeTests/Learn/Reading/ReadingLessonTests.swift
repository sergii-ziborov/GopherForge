import XCTest
@testable import GopherForge

final class ReadingLessonTests: XCTestCase {
    func testBundledReadingsAreIntegratedExactlyOnceAndPreserveOriginalCourse() {
        XCTAssertEqual(ReadingLessonCatalog.all.count, 45)
        XCTAssertEqual(GoCourseCatalog.units.count, 15)
        XCTAssertEqual(GoCourseCatalog.teachingLessons.count, 92)
        XCTAssertEqual(GoCourseCatalog.challenges.count, 22)
        XCTAssertEqual(GoCourseCatalog.lessons.count, 114)
        for reading in ReadingLessonCatalog.all {
            XCTAssertEqual(GoCourseCatalog.lessons.filter { $0.id == reading.id }.count, 1, reading.id)
            XCTAssertEqual(GoCourseCatalog.unit(containing: reading.id)?.id, reading.unitID)
            if let predecessor = reading.afterLessonID {
                let ids = GoCourseCatalog.unit(containing: reading.id)?.lessons.map(\.id) ?? []
                let before = ids.firstIndex(of: predecessor)
                let after = ids.firstIndex(of: reading.id)
                XCTAssertEqual(after, before.map { $0 + 1 }, reading.id)
            }
            if let successor = reading.beforeLessonID {
                let ids = GoCourseCatalog.unit(containing: reading.id)?.lessons.map(\.id) ?? []
                XCTAssertEqual(ids.firstIndex(of: reading.id).map { $0 + 1 },
                               ids.firstIndex(of: successor), reading.id)
            }
            XCTAssertFalse(reading.lesson.requiresCompiler)
            XCTAssertTrue(reading.lesson.canSelfReport)
            XCTAssertFalse(reading.lesson.isChallenge)
            XCTAssertNil(reading.lesson.checkSnapshot(source: ""))
        }
    }

    func testReadingsContainWorkedCodeWalkthroughsUseCasesAndOfficialReferences() {
        let hosts: Set<String> = ["go.dev", "pkg.go.dev", "gin-gonic.com", "github.com",
            "redis.io", "kubernetes.io", "www.gnu.org", "docs.docker.com", "docs.podman.io",
            "git-scm.com", "curl.se", "www.freedesktop.org"]
        for reading in ReadingLessonCatalog.all {
            XCTAssertGreaterThan(reading.introduction.count, 100, reading.id)
            XCTAssertGreaterThanOrEqual(reading.sections.count, 3, reading.id)
            XCTAssertTrue(reading.sections.contains { !($0.code ?? "").isEmpty }, reading.id)
            XCTAssertTrue(reading.sections.filter { $0.code != nil }.allSatisfy {
                ($0.walkthrough?.count ?? 0) > 80 && $0.language != nil
            }, reading.id)
            XCTAssertTrue(reading.sections.allSatisfy { $0.body.count > 100 }, reading.id)
            XCTAssertGreaterThan(reading.takeaway.count, 80, reading.id)
            XCTAssertFalse(reading.references.isEmpty, reading.id)
            XCTAssertTrue(reading.references.allSatisfy {
                $0.scheme == "https" && hosts.contains($0.host ?? "")
            }, reading.id)
        }
    }

    @MainActor
    func testReadingCompletionPersistsWithoutEverCallingTheCompiler() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "progress.json")
        let store = LearningProgressStore(storageURL: url)
        let lesson = try XCTUnwrap(GoCourseCatalog.lesson(id: "runtime.gc-reachability"))
        let model = LessonModel(lesson: lesson, store: store, testRunner: { _ in
            XCTFail("Reading a lesson must never invoke compilation")
            return .failure(phase: .test, detail: "Unexpected compiler call")
        })
        await model.prewarm()
        await model.check()
        XCTAssertFalse(model.canCheck)
        await model.markCompleted()
        XCTAssertTrue(model.isCompleted)
        XCTAssertFalse(model.isCompilerVerified)
        let restored = LearningProgressStore(storageURL: url)
        let completed = try await restored.completedLessonIDs()
        let verified = try await restored.compilerVerifiedLessonIDs()
        XCTAssertTrue(completed.contains(lesson.id))
        XCTAssertFalse(verified.contains(lesson.id))
    }
}
