import Foundation
import Observation

/// The state behind the Build side: which project is open, which file is being
/// edited, and what the toolchain last said about it.
///
/// It owns no view code and no formatting. Running a phase, recording the
/// result and keeping the idiom findings current are its whole job.
@MainActor
@Observable
final class WorkspaceModel {
    private(set) var toolchain: ToolchainStatus = .missing
    private(set) var project: GopherForgeProject?
    private(set) var projectID: UUID?
    private(set) var sourceRevision: UInt64 = 0
    private(set) var savedRevision: UInt64 = 0
    private(set) var hasUnsavedChanges = false
    private(set) var saveError: String?
    /// Retained if switching projects raced a failed disk write, so it can be retried/exported.
    private(set) var recoveryProject: GopherForgeProject?
    private(set) var lastResult: CompilationResult?
    private(set) var idiomFindings: [IdiomFinding] = []
    private(set) var isRunning = false
    private(set) var runningPhase: CompilationResult.Phase?
    /// What the toolchain is doing right now, or nil between runs. A build on a
    /// phone takes seconds, and a spinner that says nothing for that long reads
    /// as a button that does not work.
    private(set) var runningStep: GoBuildProgress?

    var selectedFile: String = "main.go"
    /// Read-only from outside so the only way in is `updateEditorText`.
    ///
    /// This was a plain `var` bound straight to the editor, which is exactly
    /// how text reached a buffer nobody saved. Closing that needs the compiler
    /// rather than a convention: `private(set)` makes the old binding fail to
    /// build instead of quietly losing work again.
    private(set) var editorText: String = ""
    /// A line the editor should scroll to and highlight, set when a search
    /// result is chosen and cleared once the editor has done it. Nil the rest
    /// of the time, so nothing scrolls on an ordinary redraw.
    private(set) var revealLine: Int?
    /// Bumped every time a run finishes, so the view can react to "a result
    /// arrived" rather than to "the result changed" — two identical runs
    /// produce equal values and the second would otherwise go unnoticed.
    private(set) var resultGeneration = 0

    /// What the navigator's search was looking for, kept so the editor can mark
    /// the same occurrences the sidebar showed. Cleared when the file is opened
    /// any other way, so ordinary navigation never leaves stale marks behind.
    var highlightQuery: String = ""

    private let compiler: WasmGoCompiler
    private let analyzer: IdiomAnalyzer
    private let library: ProjectLibrary
    private let progress: LearningProgressStore
    private var pendingBuildRecord: (id: UUID, record: ProjectBuildRecord)?
    private var compileAttempts = 0
    private var idiomTask: Task<Void, Never>?

    init(
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        library: ProjectLibrary = .shared,
        progress: LearningProgressStore = .shared
    ) {
        self.compiler = compiler
        self.analyzer = analyzer
        self.library = library
        self.progress = progress
    }

    var fileKind: SourceFileKind {
        SourceFileKind.of(path: selectedFile)
    }

    /// Lines the last result pointed at, in the file currently shown.
    var markedLines: Set<Int> {
        guard let lastResult else { return [] }
        return Set(
            lastResult.diagnostics
                .compactMap(\.span)
                .filter { $0.fileName == selectedFile }
                .map(\.line)
        )
    }

    var canRun: Bool {
        toolchain.isReady && !isRunning && project != nil
    }

    /// Choosing a main.go in the file tree selects that command for Run/Build.
    /// A non-main file keeps the project's declared entry point.
    var selectedTargetPattern: String {
        guard let project else { return "." }
        let activeIsMain = selectedFile.hasSuffix(".go")
            && !selectedFile.hasSuffix("_test.go")
            && GoSourceHeader.parse(project.files[selectedFile] ?? "").packageName == "main"
        let targetFile = activeIsMain ? selectedFile : project.entryFile
        let directory = GoPackageGraph.directory(of: targetFile)
        return directory.isEmpty ? "." : "./\(directory)"
    }

    func prepare() async {
        toolchain = compiler.probe()
        if project == nil {
            do {
                if let recent = try await library.items().first {
                    open(recent)
                } else {
                    open(ProjectTemplate.commandLineTool.project(named: "Playground"))
                }
            } catch {
                saveError = "Не удалось открыть библиотеку: \(error.localizedDescription)"
            }
        }
    }

    private var remembering: Task<Void, Never>?
    /// The pending autosave, cancelled and replaced on each edit.
    private var autosave: Task<Void, Never>?

    @discardableResult
    func open(_ project: GopherForgeProject) -> Bool {
        return open(project, id: UUID(), revision: 0, isNew: true)
    }

    @discardableResult
    func open(_ item: ProjectLibraryItem) -> Bool {
        if projectID == item.id { return true }
        return open(item.project, id: item.id, revision: item.sourceRevision ?? 0, isNew: false)
    }

    private func open(_ project: GopherForgeProject, id: UUID, revision: UInt64, isNew: Bool) -> Bool {
        commitEditorText()
        // Keep the editor and its export path available until a failed write is
        // retried. Navigating away at this point would hide the only copy.
        guard recoveryProject == nil, !(hasUnsavedChanges && saveError != nil) else { return false }
        autosave?.cancel()
        let previousSave: Task<Void, Never>?
        if let old = self.project, let oldID = projectID, hasUnsavedChanges {
            let oldRevision = sourceRevision
            previousSave = Task { await save(old, id: oldID, revision: oldRevision) }
        } else {
            previousSave = nil
        }
        self.project = project
        projectID = id
        sourceRevision = revision
        savedRevision = isNew ? 0 : revision
        hasUnsavedChanges = isNew
        if recoveryProject == nil, pendingBuildRecord == nil { saveError = nil }
        selectedFile = project.entryFile
        editorText = project.files[project.entryFile] ?? ""
        lastResult = nil
        compileAttempts = 0
        refreshIdioms()
        // A project is yours from the moment you make it. The library used to
        // hear about one only when a build finished, so anything created and
        // not yet compiled was missing from My projects — which is every
        // project, for as long as it takes to press Build.
        //
        // The task is kept so a screen that is about to list the library can
        // wait for this write rather than race it: an actor takes messages in
        // the order they arrive, and two loose tasks have no order at all.
        remembering = Task {
            await previousSave?.value
            if isNew { await save(project, id: id, revision: revision) }
        }
        return true
    }

    /// Completes once the open above has reached the library.
    func libraryUpdated() async {
        await remembering?.value
    }

    /// Opens a file and, when a line is given, asks the editor to reveal it.
    func select(file: String, revealingLine line: Int?) {
        select(file: file)
        revealLine = line
    }

    /// Called by the editor once it has scrolled, so a later redraw does not
    /// yank the view back.
    func clearReveal() {
        revealLine = nil
    }

    func select(file: String) {
        commitEditorText()
        selectedFile = file
        editorText = project?.files[file] ?? ""
        highlightQuery = ""
    }

    /// The one way the editor changes text.
    ///
    /// It folds the buffer into the project immediately and schedules the disk
    /// write. Both halves matter: the in-memory project is what Export, the
    /// package installer and every phase read, and the library is what
    /// survives the app being closed.
    ///
    /// The editor used to write `editorText` and nothing else, and the project
    /// caught up only when something asked for it — a build, or opening
    /// another file. So anything typed and not built lived in a buffer nobody
    /// persisted: leaving the tab and vendoring a package overwrote it from a
    /// stale project, and quitting lost it outright. Losing what someone typed
    /// is worse than any missing language feature.
    func updateEditorText(_ text: String) {
        guard text != editorText else { return }
        editorText = text
        commitEditorText()
    }

    /// Folds the editor buffer back into the project. Called before anything
    /// that reads the project, so a phase never compiles a stale file.
    func commitEditorText() {
        guard var project else { return }
        var files = project.files
        guard files[selectedFile] != editorText else { return }
        files[selectedFile] = editorText
        project = GopherForgeProject(
            name: project.name,
            files: files,
            entryFile: project.entryFile,
            provenance: project.provenance
        )
        self.project = project
        sourceRevision &+= 1
        hasUnsavedChanges = true
        refreshIdioms()
        scheduleAutosave()
    }

    /// Waits out a pause in typing before writing.
    ///
    /// The library is a single JSON document, so one save rewrites all of it.
    /// That is cheap between keystrokes and far too expensive on each one.
    private func scheduleAutosave() {
        autosave?.cancel()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    /// Writes the open project as it stands.
    ///
    /// Also called when the app stops being active, where there may be no
    /// later chance: a debounce that has not fired yet does not survive the
    /// process going away, so backgrounding writes rather than waits.
    func flush() async {
        commitEditorText()
        guard let project, let projectID else { return }
        await save(project, id: projectID, revision: sourceRevision)
    }

    func retrySave() async {
        if let recoveryProject, let recoveryID, let recoveryRevision {
            await save(recoveryProject, id: recoveryID, revision: recoveryRevision)
        }
        await flush()
        if let pendingBuildRecord {
            do {
                try await library.recordBuild(id: pendingBuildRecord.id, result: pendingBuildRecord.record)
                self.pendingBuildRecord = nil
                if recoveryProject == nil, !hasUnsavedChanges { saveError = nil }
            } catch {
                saveError = "Не удалось сохранить результат сборки: \(error.localizedDescription)"
            }
        }
    }

    private var recoveryID: UUID?
    private var recoveryRevision: UInt64?

    private func save(_ snapshot: GopherForgeProject, id: UUID, revision: UInt64) async {
        do {
            _ = try await library.recordSource(id: id, revision: revision, project: snapshot)
            if projectID == id {
                savedRevision = max(savedRevision, revision)
                hasUnsavedChanges = sourceRevision > savedRevision
                if recoveryProject == nil, pendingBuildRecord == nil { saveError = nil }
            }
            if recoveryID == id, recoveryRevision == revision {
                recoveryProject = nil
                recoveryID = nil
                recoveryRevision = nil
                saveError = nil
            }
        } catch {
            saveError = "Не сохранено: \(error.localizedDescription)"
            if projectID != id {
                recoveryProject = snapshot
                recoveryID = id
                recoveryRevision = revision
            }
        }
    }

    func run(_ phase: CompilationResult.Phase) async {
        commitEditorText()
        guard let project, let projectID, !isRunning else { return }
        let revision = sourceRevision
        let sourceReady = remembering

        isRunning = true
        runningPhase = phase
        defer {
            isRunning = false
            runningPhase = nil
            runningStep = nil
        }

        let snapshot = project.snapshot(
            packagePattern: phase == .run || phase == .build ? selectedTargetPattern : "./...",
            workspaceReuseKey: projectID.uuidString
        )
        let result = await execute(phase: phase, snapshot: snapshot, projectID: projectID)
        if self.projectID == projectID, sourceRevision == revision {
            lastResult = result
            resultGeneration += 1
        }
        compileAttempts += 1

        if phase == .format, result.succeeded,
           self.projectID == projectID, sourceRevision == revision {
            // gofmt rewrites files in place; the editor must show what the
            // toolchain produced rather than what the user typed.
            apply(formattedFiles: result.formattedFiles)
        }

        do {
            await sourceReady?.value
            try await library.recordBuild(id: projectID, result: ProjectBuildRecord(result: result))
        } catch {
            pendingBuildRecord = (projectID, ProjectBuildRecord(result: result))
            saveError = "Не удалось сохранить результат сборки: \(error.localizedDescription)"
        }
        // The library keeps the last build per project, which cannot answer
        // "how much have you actually run". This is the counted record the
        // badges read.
        try? await progress.record(PracticeRun(result: result))
    }

    /// What the built-artifact cache occupies on this device.
    var buildCacheByteCount: Int64 {
        compiler.buildCacheByteCount
    }

    /// Forgets every built artifact. The next build recompiles from source,
    /// which is slower and is the point: this is here so storage can be
    /// reclaimed, and so a build can be forced to happen for real.
    func clearBuildCache() {
        compiler.clearBuildCache()
    }

    /// Drops a vendored module the way installing added it: the `vendor/`
    /// tree, the `require` line and the checksums, in one write.
    func removePackage(_ modulePath: String) {
        guard let files = project?.files else { return }
        replaceFiles(with: GoVendorWriter.remove(modulePath: modulePath, from: files))
    }

    /// Replaces the whole file set, which is what installing a package does.
    ///
    /// The open file is kept if it survived the change, so vendoring a
    /// dependency does not move the user out of what they were editing.
    func replaceFiles(with files: [String: String]) {
        guard let project else { return }
        let updated = GopherForgeProject(
            name: project.name,
            files: files,
            entryFile: project.entryFile,
            provenance: project.provenance
        )
        self.project = updated
        sourceRevision &+= 1
        hasUnsavedChanges = true
        if files[selectedFile] == nil {
            selectedFile = updated.entryFile
        }
        editorText = files[selectedFile] ?? ""
        refreshIdioms()
        scheduleAutosave()
    }

    /// Filing edits the library item while the editor may have newer unsaved
    /// files. Refresh only the name; keep the live source and its revision.
    func refreshMetadata(from item: ProjectLibraryItem) {
        guard projectID == item.id, let project else { return }
        self.project = GopherForgeProject(
            name: item.project.name,
            files: project.files,
            entryFile: project.entryFile,
            provenance: project.provenance
        )
    }

    func applyIdiom(_ finding: IdiomFinding) {
        guard let expected = IdiomRepair.line(at: finding, in: editorText),
              let repaired = try? IdiomRepair.apply(finding, to: editorText, expectedLine: expected)
        else {
            return
        }
        editorText = repaired
        commitEditorText()
    }

    private func execute(
        phase: CompilationResult.Phase,
        snapshot: GoSourceSnapshot,
        projectID: UUID
    ) async -> CompilationResult {
        // The compiler reports from its own queue and must stay unaware that a
        // main actor exists, so the hop happens here, once, for every phase.
        let report: GoBuildProgressHandler = { [weak self] progress in
            Task { @MainActor in
                guard self?.projectID == projectID else { return }
                self?.runningStep = progress
            }
        }

        return switch phase {
        case .format: await compiler.format(project: snapshot, onProgress: report)
        case .vet: await compiler.vet(project: snapshot, onProgress: report)
        case .build: await compiler.build(project: snapshot, onProgress: report)
        case .run: await compiler.run(project: snapshot, onProgress: report)
        case .test: await compiler.test(project: snapshot, onProgress: report)
        case .setup: .failure(phase: .setup, detail: "Setup is not a runnable phase.")
        }
    }

    /// Takes what gofmt wrote in the job sandbox and makes it the project.
    ///
    /// Only the files the formatter actually rewrote are touched, so a run
    /// that changed nothing leaves every buffer — and the caret in the open
    /// one — exactly where it was.
    private func apply(formattedFiles: [String: String]) {
        guard var project, !formattedFiles.isEmpty else { return }
        var files = project.files
        var changed = false
        for (path, contents) in formattedFiles where files[path] != contents {
            files[path] = contents
            changed = true
        }
        guard changed else { return }

        project = GopherForgeProject(
            name: project.name,
            files: files,
            entryFile: project.entryFile,
            provenance: project.provenance
        )
        self.project = project
        sourceRevision &+= 1
        hasUnsavedChanges = true
        if let reformatted = files[selectedFile] { editorText = reformatted }
        refreshIdioms()
        scheduleAutosave()
    }

    private func refreshIdioms() {
        guard let project else {
            idiomFindings = []
            return
        }
        let id = projectID
        let revision = sourceRevision
        let snapshot = project.snapshot()
        let analyzer = analyzer
        idiomTask?.cancel()
        idiomFindings = []
        idiomTask = Task.detached { [weak self] in
            let findings = analyzer.analyze(snapshot)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.projectID == id, self.sourceRevision == revision else { return }
                self.idiomFindings = findings
            }
        }
    }
}
