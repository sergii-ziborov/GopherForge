import XCTest
@testable import GopherForge

/// Every lesson that asks for code is solvable, proved by solving it.
///
/// A lesson ships a starter and a hidden test, and nothing else in the product
/// checks that the two can ever be reconciled. If they cannot, the only person
/// who finds out is a learner who tries and concludes they are stupid. So this
/// compiles a complete answer against each hidden test with the real toolchain
/// and requires the test to pass.
///
/// It found one the first time it ran: the select lesson's hidden test called
/// `waitFor(values, ctx)` while the lesson taught context first.
final class LessonSolutionGateTests: XCTestCase {
    private var compiler: WasmGoCompiler!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GOPHERFORGE_RUN_COMPILER_GATE"] == "1",
            "Run the GopherForgeCompilerGate scheme to execute the bundled-toolchain gates."
        )
        compiler = WasmGoCompiler()
    }

    func testEveryCompileLessonHasAnAnswerThatPassesItsOwnTest() async throws {
        var failures: [String] = []

        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            guard case let .compile(_, hiddenTest) = lesson.task else { continue }
            guard let solution = lesson.verifiedSolution else {
                failures.append("\(lesson.id): no verified solution")
                continue
            }

            let result = await compiler.test(
                project: GoSourceSnapshot(
                    files: [
                        "go.mod": GoLanguage.module("lesson"),
                        "main.go": solution,
                        "main_test.go": hiddenTest,
                    ],
                    packagePattern: ".",
                    entryFile: "main.go"
                )
            )

            if !result.succeeded {
                failures.append(
                    """
                    \(lesson.id): the answer does not pass the lesson's own test
                    detail: \(result.detail)
                    stdout: \(result.stdout)
                    stderr: \(result.stderr)
                    """
                )
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n\n"))
    }

    /// The starter must not already pass, or the lesson asks for nothing.
    func testAStarterDoesNotAlreadyPass() async throws {
        var passing: [String] = []

        for lesson in GoCourseCatalog.lessons where lesson.requiresCompiler {
            guard case let .compile(starter, hiddenTest) = lesson.task else { continue }
            let result = await compiler.test(
                project: GoSourceSnapshot(
                    files: [
                        "go.mod": GoLanguage.module("lesson"),
                        "main.go": starter,
                        "main_test.go": hiddenTest,
                    ],
                    packagePattern: ".",
                    entryFile: "main.go"
                )
            )
            if result.succeeded { passing.append(lesson.id) }
        }

        XCTAssertTrue(
            passing.isEmpty,
            "these lessons are already solved before the learner starts: \(passing)"
        )
    }

    /// The phone flow is not a fresh compile: opening the lesson prewarms its
    /// answer, the learner's first Check fails, and Realize then replaces that
    /// source in the same persistent work tree. This is the exact regression
    /// sequence from the UI, including the stable reuse key.
    @MainActor
    func testRealizePassesAfterAFailedCheckInTheReusedLessonWorkspace() async throws {
        let lesson = try XCTUnwrap(GoCourseCatalog.lesson(id: "core.multiple-returns"))
        let reuseKey = "lesson.\(lesson.id)"
        let workRoot = GoWorkspaceStager.persistentRootURL(for: reuseKey)
        try? FileManager.default.removeItem(at: workRoot)
        defer { try? FileManager.default.removeItem(at: workRoot) }

        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "gopherforge-realize-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let model = LessonModel(
            lesson: lesson,
            compiler: compiler,
            store: LearningProgressStore(storageURL: storeURL)
        )

        await model.prewarm()
        await model.check()
        let failedResult = try XCTUnwrap(model.result)
        XCTAssertEqual(failedResult.tests.failedCount, 2)
        XCTAssertTrue(
            failedResult.tests.contains { !$0.output.isEmpty },
            "A failed hidden test must carry the message the lesson UI shows"
        )

        await model.realizeAndCheck()
        let result = try XCTUnwrap(model.result)
        XCTAssertTrue(
            result.succeeded,
            "Realize source failed: \(result.detail)\n\(result.stdout)\n\(result.stderr)"
        )
        XCTAssertEqual(result.tests.passedCount, 2)
    }
}
