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
    var editorText: String {
        didSet {
            guard !isRestoringDraft, !editorText.utf8.elementsEqual(oldValue.utf8) else { return }
            draftRevision &+= 1
            queueDraftSave()
        }
    }
    private(set) var assistanceLevel = LessonAssistance.none
    private(set) var ownTextBeforeSolution: String?
    private(set) var draftContentChanged = false
    private(set) var draftSaveError: String?
    private(set) var draftRestored = false
    private let drafts: LessonDraftStore
    private var draftToken: UUID?
    private var draftRevision: UInt64 = 0
    private var draftContentRevision: String
    private var isRestoringDraft = false
    private var isLoadingDraft = false
    private var draftSaveTask: Task<Void, Never>?

    private let analyzer: IdiomAnalyzer
    private let store: LearningProgressStore
    private let toolchain: ToolchainStatus
    private let testRunner: @Sendable (GoSourceSnapshot) async -> CompilationResult
    private var attempts = 0
    private var prewarmTask: Task<CompilationResult?, Never>?
    private var prewarmedSource: String?
    private var prewarmedResult: CompilationResult?

    init(
        lesson: Lesson,
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        store: LearningProgressStore = .shared,
        drafts: LessonDraftStore? = nil,
        toolchainStatus: ToolchainStatus? = nil,
        testRunner: (@Sendable (GoSourceSnapshot) async -> CompilationResult)? = nil
    ) {
        self.lesson = lesson
        self.analyzer = analyzer
        self.store = store
        self.drafts = drafts ?? store.drafts
        draftContentRevision = LessonDraftStore.contentRevision(for: lesson)
        toolchain = toolchainStatus ?? compiler.probe()
        self.testRunner = testRunner ?? { project in
            await compiler.test(project: project)
        }
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
        await loadDraft()
        isCompleted = ((try? await store.completedLessonIDs()) ?? []).contains(lesson.id)
        isCompilerVerified =
            ((try? await store.compilerVerifiedLessonIDs()) ?? []).contains(lesson.id)
    }

    private func loadDraft() async {
        guard lesson.requiresCompiler, draftToken == nil, !isLoadingDraft else { return }
        isLoadingDraft = true
        defer { isLoadingDraft = false }
        do {
            let session = try await drafts.open(lessonID: lesson.id)
            draftToken = session.token
            if let draft = session.draft, draftRevision == 0 {
                isRestoringDraft = true
                editorText = draft.text
                isRestoringDraft = false
                ownTextBeforeSolution = draft.ownTextBeforeSolution
                assistanceLevel = draft.assistance
                draftContentChanged = draft.contentRevision != LessonDraftStore.contentRevision(for: lesson)
                draftContentRevision = draft.contentRevision
                draftRestored = true
            }
            draftSaveError = nil
            if draftRevision > 0 { await saveDraft() }
        } catch { draftSaveError = error.localizedDescription }
    }

    private func queueDraftSave() {
        guard lesson.requiresCompiler else { return }
        draftSaveTask?.cancel()
        draftSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.saveDraft()
        }
    }

    /// Called on leaving/backgrounding as well as after the short typing debounce.
    func saveDraft() async {
        guard lesson.requiresCompiler else { return }
        guard let token = draftToken else { await loadDraft(); return }
        let revision = draftRevision
        let draft = LessonDraft(
            lessonID: lesson.id, contentRevision: draftContentRevision,
            text: editorText, ownTextBeforeSolution: ownTextBeforeSolution,
            assistance: assistanceLevel, updatedAt: Date()
        )
        do {
            try await drafts.save(draft, token: token, revision: revision)
            if draftRevision == revision { draftSaveError = nil }
        } catch { draftSaveError = error.localizedDescription }
    }

    func noteHintRead() {
        if assistanceLevel == .none { assistanceLevel = .hint; draftRevision &+= 1; queueDraftSave() }
    }

    func noteSolutionRevealed() {
        guard assistanceLevel != .solutionInserted else { return }
        assistanceLevel = .solutionRevealed
        draftRevision &+= 1
        queueDraftSave()
    }

    /// Restores the learner's source; seeing the answer remains part of this attempt.
    func restoreOwnCode() {
        guard let ownTextBeforeSolution else { return }
        editorText = ownTextBeforeSolution
        result = nil
    }

    /// Explicitly starts a new attempt. It does not reset completion history.
    func resetDraft() {
        draftContentRevision = LessonDraftStore.contentRevision(for: lesson)
        draftContentChanged = false
        ownTextBeforeSolution = nil
        assistanceLevel = .none
        editorText = Self.starter(for: lesson)
        result = nil
        draftRevision &+= 1
        queueDraftSave()
    }

    /// Compiles the verified answer (or the starter) into the reused work
    /// tree so Check only has to rebuild what the learner edited. Its result is
    /// retained as well: Realize inserts this exact verified source, so running
    /// the same hidden test for a second minute would prove nothing new.
    func prewarm() async {
        guard lesson.requiresCompiler, toolchain.isReady, prewarmTask == nil,
              prewarmedResult == nil, !isChecking else { return }
        isPrewarming = true
        let source = lesson.verifiedSolution ?? editorText
        prewarmedSource = source
        let task = Task<CompilationResult?, Never> { [testRunner] in
            guard let snapshot = lesson.checkSnapshot(source: source) else { return nil }
            return await testRunner(snapshot)
        }
        prewarmTask = task
        prewarmedResult = await task.value
        prewarmTask = nil
        isPrewarming = false
    }

    /// Puts the verified answer in the editor. Check still has to run: Realize
    /// is a fill, not a pass. The old failed verdict is cleared so the screen
    /// never claims that the newly inserted answer is the source that failed.
    func realize() {
        guard let source = LessonHintCatalog.realizeSource(for: lesson) else { return }
        if ownTextBeforeSolution == nil { ownTextBeforeSolution = editorText }
        assistanceLevel = .solutionInserted
        draftRevision &+= 1
        editorText = source
        queueDraftSave()
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
                compilerVerified: false,
                assistanceLevel: assistanceLevel
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
        guard case .compile = lesson.task, toolchain.isReady, !isChecking else { return }

        // Claim the check before the first suspension. Previously this flag was
        // set only after waiting for prewarm, so every impatient tap queued a
        // second test of the old source. Those stale tests could then overwrite
        // the result produced by Realize.
        isChecking = true
        defer { isChecking = false }
        await loadDraft()

        if let task = prewarmTask {
            prewarmedResult = await task.value
            prewarmTask = nil
            isPrewarming = false
        }

        let source = editorText
        let assistance = assistanceLevel
        await saveDraft()
        guard let snapshot = lesson.checkSnapshot(source: source) else { return }

        let outcome: CompilationResult
        if let prewarmedSource, source.utf8.elementsEqual(prewarmedSource.utf8), let cached = prewarmedResult {
            outcome = cached
            // Reuse only for the hand-off from prewarm to the first exact
            // Check. A later press should really run the tests again.
            self.prewarmedSource = nil
            prewarmedResult = nil
        } else {
            outcome = await testRunner(snapshot)
        }

        result = outcome
        attempts += 1
        if outcome.succeeded {
            isCompleted = true
            isCompilerVerified = true
        }

        let findings = analyzer.analyze(source: source, fileName: "main.go")
        try? await store.record(
            LessonAttempt.from(
                lessonID: lesson.id,
                result: outcome,
                findings: findings,
                compileAttempts: attempts,
                assistanceLevel: assistance
            )
        )
    }

    private static func starter(for lesson: Lesson) -> String {
        switch lesson.task {
        case .reading: ""
        case let .compile(starter, _): starter
        case let .guidedTyping(target): target
        case let .fillGaps(template, _): template
        case let .predict(source, _, _): source
        }
    }
}
