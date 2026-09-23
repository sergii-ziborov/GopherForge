import Foundation
import Observation

/// Runs one lesson's attempt and records what it taught.
///
/// The hidden test is compiled and executed by the same toolchain the Build
/// side uses. A lesson passes when `go test` passes; nothing here inspects the
/// learner's text to decide. A pass is recorded automatically. Skip is Next.
@MainActor
@Observable
final class LessonModel {
    let lesson: Lesson

    private(set) var result: CompilationResult?
    private(set) var isChecking = false
    private(set) var isPrewarming = false
    /// Whether this lesson has ever been passed, loaded when the screen opens
    /// so a lesson you finished last week still looks finished.
    private(set) var isCompleted = false
    /// Whether the pass on record is one the compiler witnessed. A lesson the
    /// learner ticked is done, and is not the same claim.
    private(set) var isCompilerVerified = false
    var editorText: String

    private let compiler: WasmGoCompiler
    private let analyzer: IdiomAnalyzer
    private let store: LearningProgressStore
    private let toolchain: ToolchainStatus
    private var attempts = 0
    private var compileTask: Task<CompilationResult?, Never>?

    init(
        lesson: Lesson,
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        store: LearningProgressStore = .shared
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

    var canSelfReport: Bool { lesson.canSelfReport }

    var canRealize: Bool { LessonHintCatalog.realizeSource(for: lesson) != nil }

    var hint: LessonHint { LessonHintCatalog.hint(for: lesson) }

    var toolchainDetail: String { "\(toolchain.label). \(toolchain.detail)" }

    func loadProgress() async {
        isCompleted = ((try? await store.completedLessonIDs()) ?? []).contains(lesson.id)
        isCompilerVerified =
            ((try? await store.compilerVerifiedLessonIDs()) ?? []).contains(lesson.id)
    }

    /// Compiles the verified answer (or the starter) into the reused work
    /// tree so Check only has to rebuild what the learner edited.
    func prewarm() async {
        guard lesson.requiresCompiler, toolchain.isReady, compileTask == nil else { return }
        isPrewarming = true
        defer { isPrewarming = false }
        let source = lesson.verifiedSolution ?? editorText
        compileTask = Task { [compiler] in
            guard let snapshot = lesson.checkSnapshot(source: source) else { return nil }
            return await compiler.test(project: snapshot)
        }
        _ = await compileTask?.value
        compileTask = nil
    }

    /// Puts the verified answer in the editor. Check still has to run: Realize
    /// is a fill, not a pass. The old failed verdict is cleared so the screen
    /// never claims that the newly inserted answer is the source that failed.
    func realize() {
        guard let source = LessonHintCatalog.realizeSource(for: lesson) else { return }
        editorText = source
        result = nil
    }

    /// The action offered after a failed Check is deliberately end-to-end:
    /// insert the catalogued answer and have the same hidden test verify it.
    /// A learner asking to see the answer should not have to guess whether a
    /// stale red verdict belongs to the old source or press a second button.
    func realizeAndCheck() async {
        realize()
        await check()
    }

    /// Records a lesson the compiler cannot judge.
    func markCompleted() async {
        guard canSelfReport, !isCompleted else { return }
        isCompleted = true
        isCompilerVerified = false
        try? await store.record(
            LessonAttempt(
                lessonID: lesson.id,
                succeeded: true,
                mistakeTags: [],
                compileAttempts: 0,
                compilerVerified: false
            )
        )
    }

    /// Undoes a tick made by hand. A pass the compiler witnessed stays, because
    /// it happened.
    func clearCompletion() async {
        _ = try? await store.clearSelfReportedCompletion(lessonID: lesson.id)
        await loadProgress()
    }

    func check() async {
        guard case .compile = lesson.task, !isChecking else { return }
        if let compileTask { _ = await compileTask.value }
        isChecking = true
        defer { isChecking = false }

        guard let snapshot = lesson.checkSnapshot(source: editorText) else { return }
        compileTask = Task { [compiler] in
            await compiler.test(project: snapshot)
        }
        let outcome = await compileTask?.value
        compileTask = nil
        guard let outcome else { return }
        result = outcome
        attempts += 1
        if outcome.succeeded {
            isCompleted = true
            isCompilerVerified = true
        }

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
