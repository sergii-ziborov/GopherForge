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
}
