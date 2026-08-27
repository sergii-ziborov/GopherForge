import Foundation
import Observation

/// Runs one lesson's attempt and records what it taught.
///
/// The hidden test is compiled and executed by the same toolchain the Build
/// side uses. A lesson passes when `go test` passes; nothing here inspects the
/// learner's text to decide.
@MainActor
@Observable
final class LessonModel {
    let lesson: Lesson

    private(set) var result: CompilationResult?
    private(set) var isChecking = false
    var editorText: String

    private let compiler: WasmGoCompiler
    private let analyzer: IdiomAnalyzer
    private let store: LearningProgressStore
    private let toolchain: ToolchainStatus
    private var attempts = 0

    init(
        lesson: Lesson,
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        store: LearningProgressStore = LearningProgressStore()
    ) {
        self.lesson = lesson
        self.compiler = compiler
        self.analyzer = analyzer
        self.store = store
        toolchain = compiler.probe()
        editorText = LessonModel.starter(for: lesson)
    }

    /// A compile lesson is verified by the real toolchain, so without one there
    /// is nothing to check and the app says so rather than offering a button
    /// that can only fail.
    var canCheck: Bool { lesson.requiresCompiler && toolchain.isReady && !isChecking }

    var toolchainDetail: String { "\(toolchain.label). \(toolchain.detail)" }

    func check() async {
        guard case let .compile(_, hiddenTest) = lesson.task, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let snapshot = GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module("lesson"),
                "main.go": editorText,
                "lesson_test.go": hiddenTest,
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )

        let outcome = await compiler.test(project: snapshot)
        result = outcome
        attempts += 1

        let findings = analyzer.analyze(source: editorText, fileName: "main.go")
        try? await store.record(
            LessonAttempt.from(
                lessonID: lesson.id,
                result: outcome,
                findings: findings,
                compileAttempts: attempts
            )
        )
    }

    private static func starter(for lesson: Lesson) -> String {
        switch lesson.task {
        case let .compile(starter, _): starter
        case let .guidedTyping(target): target
        case let .fillGaps(template, _): template
        case let .predict(source, _, _): source
        }
    }
}
