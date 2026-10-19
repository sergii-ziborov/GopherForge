import XCTest
@testable import GopherForge

final class OperationsReadingTests: XCTestCase {
    func testPracticalUnitsRemainReachableAndFeedReviewAndMistakes() throws {
        let counts = ["operations": 11, "containers": 6, "kubernetes": 8]
        for (id, count) in counts {
            let unit = try XCTUnwrap(GoCourseCatalog.unit(id: id))
            XCTAssertEqual(unit.teachingLessons.count, count)
            XCTAssertTrue(unit.teachingLessons.allSatisfy { !$0.requiresCompiler })
            for lesson in unit.teachingLessons {
                let reading = try XCTUnwrap(ReadingLessonCatalog.reading(for: lesson.id))
                XCTAssertGreaterThanOrEqual(reading.sections.filter { $0.code != nil }.count, 2, lesson.id)
                XCTAssertTrue(ReviewMatchCatalog.allPairs.contains {
                    $0.requiredLessonID == lesson.id && $0.prompt == reading.reviewPrompt
                }, lesson.id)
                let entry = try XCTUnwrap(MistakeReviewCatalog.all.first {
                    $0.question.id == "reading.question.\(lesson.id)"
                })
                XCTAssertEqual(entry.unitID, id)
                XCTAssertEqual(entry.question.options.count, 3)
                XCTAssertEqual(Set(entry.question.options).count, 3)
                XCTAssertNotNil(LessonSymbol.byConcept[reading.conceptTag])
            }
        }
        XCTAssertEqual(GoCourseCatalog.lesson(after: "operations.linux-service")?.id, "operations.docker-build")
        XCTAssertEqual(GoCourseCatalog.lesson(after: "operations.container-registry")?.id, "operations.kubernetes-contexts")
    }

    func testExistingReadingIdentifiersRemainAvailableForSavedCompletion() {
        for id in ["bash-arguments", "bash-failures", "docker-build", "podman-runtime",
                   "kubernetes-workloads", "probes-and-shutdown"] {
            XCTAssertNotNil(GoCourseCatalog.lesson(id: "operations.\(id)"))
        }
    }

    func testCommandsCoverActualInvestigationAndDeploymentWorkflows() throws {
        func code(_ suffix: String) throws -> String {
            try XCTUnwrap(ReadingLessonCatalog.reading(for: "operations.\(suffix)"))
                .sections.compactMap(\.code).joined(separator: "\n")
        }
        XCTAssertTrue(try code("shell-files").contains("mktemp -d"))
        XCTAssertTrue(try code("shell-scripts").contains("trap "))
        XCTAssertTrue(try code("docker-compose").contains("config --quiet"))
        XCTAssertTrue(try code("kubernetes-contexts").contains("auth can-i"))
        XCTAssertTrue(try code("kubernetes-inspect").contains("--previous"))
        XCTAssertTrue(try code("kubernetes-network").contains("port-forward"))
        XCTAssertTrue(try code("kubernetes-rollout").contains("rollout undo"))
        let kube = ReadingLessonCatalog.all.filter { $0.unitID == "kubernetes" }
        for lesson in kube {
            for section in lesson.sections where section.language == "bash" {
                for line in (section.code ?? "").split(separator: "\n") where line.hasPrefix("kubectl ") && !line.hasPrefix("kubectl config ") {
                    XCTAssertTrue(line.contains("--context dev-cluster"), "\(lesson.id): \(line)")
                }
            }
        }
    }
}
