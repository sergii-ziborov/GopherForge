import XCTest
@testable import GopherForge

final class ReadingLessonTests: XCTestCase {
    func testNewCurriculumIsReachableAndHasIndependentReviewEvidence() throws {
        let ids = GoConcept.curriculumExpansionTags
        XCTAssertEqual(ids.count, 15)
        XCTAssertEqual(GoCourseCatalog.unit(id: "sql")?.teachingLessons.count, 5)
        XCTAssertEqual(GoCourseCatalog.unit(id: "ai")?.teachingLessons.count, 4)
        for id in ids {
            let reading = try XCTUnwrap(ReadingLessonCatalog.reading(for: id))
            XCTAssertEqual(reading.conceptTag, id)
            XCTAssertEqual(GoCourseCatalog.lessons.filter { $0.id == id }.count, 1)
            XCTAssertTrue(GoConcept.all.contains(id))
            XCTAssertNotNil(LessonSymbol.byConcept[id])
            XCTAssertEqual(reading.designGuide?.flow.count, 4)
            XCTAssertNotNil(ReviewMatchCatalog.allPairs.first { $0.requiredLessonID == id })
            XCTAssertNotNil(MistakeReviewCatalog.all.first { $0.id == "reading.question.\(id)" })
        }
    }

    func testBufferOwnershipLessonsHaveDistinctReviewAndMistakeEvidence() throws {
        for id in ["stdlib.borrowed-buffers", "runtime.pool-ownership"] {
            let reading = try XCTUnwrap(ReadingLessonCatalog.reading(for: id))
            XCTAssertEqual(reading.conceptTag, id)
            XCTAssertTrue(GoConcept.all.contains(id))
            XCTAssertNotNil(LessonSymbol.byConcept[id])
            XCTAssertEqual(GoCourseCatalog.lessons.filter { $0.id == id }.count, 1)
            XCTAssertEqual(GoCourseCatalog.unit(containing: id)?.id, reading.unitID)
            let pair = try XCTUnwrap(ReviewMatchCatalog.allPairs.first { $0.requiredLessonID == id })
            XCTAssertEqual(pair.answer, reading.reviewAnswer)
            XCTAssertLessThanOrEqual(pair.prompt.count, MatchingDrill.maximumPromptCharacters)
            XCTAssertLessThanOrEqual(pair.answer.count, MatchingDrill.maximumAnswerCharacters)
            let check = try XCTUnwrap(MistakeReviewCatalog.all.first { $0.id == "reading.question.\(id)" })
            XCTAssertEqual(Set(check.question.options).count, 3)
            XCTAssertEqual(reading.designGuide?.flow.count, 4)
        }
    }

    func testEnvironmentExpansionIsReachableAndHasIndependentReviewEvidence() throws {
        let expanded = ReadingLessonCatalog.all.filter { GoConcept.environmentLessonTags.contains($0.id) }
        XCTAssertEqual(expanded.count, 24)
        XCTAssertEqual(Set(expanded.map(\.conceptTag)).count, 24)
        XCTAssertEqual(GoCourseCatalog.unit(id: "modules")?.teachingLessons.count, 14)
        XCTAssertEqual(GoCourseCatalog.unit(id: "datastores")?.teachingLessons.count, 12)
        XCTAssertEqual(GoCourseCatalog.lesson(after: "modules.tests")?.id, "modules.identity-versions")
        XCTAssertEqual(GoCourseCatalog.lesson(after: "modules.startup-ownership")?.id, "concurrency.cancel-and-join")
        for reading in expanded {
            XCTAssertEqual(GoCourseCatalog.lessons.filter { $0.id == reading.id }.count, 1)
            XCTAssertNotNil(reading.designGuide)
            XCTAssertTrue(GoConcept.all.contains(reading.conceptTag))
            XCTAssertNotNil(LessonSymbol.byConcept[reading.conceptTag])
            XCTAssertLessThanOrEqual(reading.reviewPrompt.count, MatchingDrill.maximumPromptCharacters)
            XCTAssertLessThanOrEqual(reading.reviewAnswer.count, MatchingDrill.maximumAnswerCharacters)
            let match = try XCTUnwrap(ReviewMatchCatalog.allPairs.first { $0.requiredLessonID == reading.id })
            XCTAssertEqual(match.answer, reading.reviewAnswer)
            let question = try XCTUnwrap(MistakeReviewCatalog.all.first { $0.id == "reading.question.\(reading.id)" })
            XCTAssertEqual(question.question.options.count, 3)
            XCTAssertEqual(Set(question.question.options).count, 3)
        }
    }

    func testBundledReadingsAreIntegratedExactlyOnceAndPreserveOriginalCourse() {
        XCTAssertEqual(ReadingLessonCatalog.all.count, 173)
        XCTAssertEqual(GoCourseCatalog.units.count, 28)
        XCTAssertEqual(GoCourseCatalog.teachingLessons.count, 220)
        XCTAssertEqual(GoCourseCatalog.challenges.count, 22)
        XCTAssertEqual(GoCourseCatalog.lessons.count, 242)
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
            "redis.io", "www.mongodb.com", "kubernetes.io", "www.gnu.org", "docs.docker.com", "docs.podman.io",
            "git-scm.com", "curl.se", "www.freedesktop.org", "blog.cleancoder.com",
            "alistair.cockburn.us", "jeffreypalermo.com", "www.jimmybogard.com",
            "www.domainlanguage.com", "martinfowler.com", "learn.microsoft.com",
            "grpc.io", "docs.aws.amazon.com", "www.informit.com", "gopherforge.app",
            "developers.openai.com", "learn.chatgpt.com", "code.claude.com", "cursor.com",
            "www.postgresql.org", "microservices.io", "opentelemetry.io", "geth.ethereum.org",
            "ethereum.org", "eips.ethereum.org", "www.rfc-editor.org", "owasp.org",
            "modelcontextprotocol.io", "protobuf.dev", "kafka.apache.org", "raft.github.io", "www.microsoft.com", "www.cs.columbia.edu"]
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
        let lesson = try XCTUnwrap(GoCourseCatalog.lesson(id: "runtime.pool-ownership"))
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
