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
    private(set) var projectGeneration = 0
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
    /// Set while repository modules are downloading. Closing it keeps every
    /// package already written and stops the one in flight.
    private(set) var moduleDownload: ModuleDownload?
    private var moduleDownloadCancelled = false
    private var moduleAttemptName: String?
    private var moduleAttemptStarted: Date?
    private var currentModuleTask: Task<GoPackageInstaller.Result, Error>?
    /// Packages the last download could not keep. Shown in Output, with Retry.
    private(set) var packageProblems: [PackageDownloadProblem] = []

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
    var revealLine: Int?
    /// The diagnostic the owner just opened. Marked in the editor until they
    /// start editing that line; a compile mark that stays after the first
    /// keystroke is arguing with the text they are writing.
    var focusedErrorFile: String?
    var focusedErrorLine: Int?
    /// Bumped every time a run finishes, so the view can react to "a result
    /// arrived" rather than to "the result changed" — two identical runs
    /// produce equal values and the second would otherwise go unnoticed.
    private(set) var resultGeneration = 0

    /// What the navigator's search was looking for, kept so the editor can mark
    /// the same occurrences the sidebar showed. Cleared when the file is opened
    /// any other way, so ordinary navigation never leaves stale marks behind.
    var highlightQuery: String = ""
    /// Loopback URL for a project that has pages. Nil for everything else.
    var sitePreviewURL: URL?
    /// Bumped when the served files change so the preview reloads.
    var siteGeneration = 0
    let siteServer = LocalSiteServer()

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
        if projectID == item.id {
            commitEditorText()
            selectedFile = project?.entryFile ?? item.project.entryFile
            editorText = project?.files[selectedFile] ?? ""
            resetProjectPresentation()
            return true
        }
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
        resetProjectPresentation()
        compileAttempts = 0
        refreshIdioms()
        // A project is yours from the moment you make it. The library used to
        // hear about one only when a build finished, so anything created and
        // not yet compiled was missing from Project library — which is every
        // project, for as long as it takes to press Build.
        //
        // The task is kept so a screen that is about to list the library can
        // wait for this write rather than race it: an actor takes messages in
        // the order they arrive, and two loose tasks have no order at all.
        remembering = Task {
            await previousSave?.value
            if isNew { await save(project, id: id, revision: revision) }
        }
        refreshSitePreview()
        return true
    }

    private func resetProjectPresentation() {
        projectGeneration &+= 1
        lastResult = nil
        runningStep = nil
        revealLine = nil
        highlightQuery = ""
        clearFocusedError()
    }

    /// Completes once the open above has reached the library.
    func libraryUpdated() async {
        await remembering?.value
    }

    /// The focus extension writes the buffer; this is the only setter it has.
    func replaceEditorText(_ text: String) {
        editorText = text
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
        syncSiteFiles()
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

        isRunning = true
        runningPhase = phase
        defer {
            isRunning = false
            runningPhase = nil
            runningStep = nil
        }

        let pattern = phase == .run || phase == .build ? selectedTargetPattern : "./..."
        if phase != .format, phase != .setup, needsModuleDownload(project, phase: phase, pattern: pattern) {
            beginModuleDownload(title: project.name, status: "Preparing packages…")
        }
        moduleDownloadCancelled = false
        let vendored = await addingMissingModules(to: project, phase: phase, pattern: pattern)
        moduleDownload = nil
        if moduleDownloadCancelled {
            moduleDownloadCancelled = false
            return
        }
        if vendored.files != project.files {
            replaceFiles(with: vendored.files)
        }
        let ready = self.project ?? vendored

        let revision = sourceRevision
        let opening = projectGeneration
        let sourceReady = remembering
        let snapshot = ready.snapshot(
            packagePattern: pattern,
            workspaceReuseKey: projectID.uuidString
        )
        let result = await execute(phase: phase, snapshot: snapshot, projectID: projectID)
        await record(
            result,
            phase: phase,
            projectID: projectID,
            revision: revision,
            opening: opening,
            sourceReady: sourceReady
        )
    }

    /// Downloads a GitHub repository and the modules its entry package imports.
    ///
    /// The snapshot alone is not a buildable project: `go.mod` names modules
    /// that are not in the archive. They are vendored here, before the editor
    /// opens, so Run is not the first moment the absence shows up.
    func dismissModuleDownload() {
        moduleDownloadCancelled = true
        currentModuleTask?.cancel()
        moduleDownload = nil
    }

    /// A download that was alive when the screen slept often never resumes.
    /// If the same package has been the current one for a while of real time,
    /// drop it and move on. What already landed stays in the project.
    func interruptStalledDownload() {
        guard isRunning, let started = moduleAttemptStarted else { return }
        guard Date().timeIntervalSince(started) > 45 else { return }
        currentModuleTask?.cancel()
    }

    func importGitHub(_ reference: GitHubRepositoryReference) async throws -> GopherForgeProject {
        beginModuleDownload(
            title: reference.displayName,
            status: "Downloading \(reference.displayName)…"
        )
        do {
            let downloaded = try await GitHubRepositoryImporter().importRepository(reference)
            let directory = GoPackageGraph.directory(of: downloaded.entryFile)
            let pattern = directory.isEmpty ? "." : "./\(directory)"
            noteDownload("Adding packages…")
            let ready = await addingMissingModules(to: downloaded, phase: .build, pattern: pattern)
            moduleDownload = nil
            if !packageProblems.isEmpty {
                lastResult = .failure(
                    phase: .setup,
                    detail: packageProblems.map(\.outputLine).joined(separator: "\n")
                )
            }
            return ready
        } catch {
            failModuleDownload((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            throw error
        }
    }

    /// Tries the packages Output reported, then leaves the project open either way.
    func retryPackageDownloads() async {
        guard let project, !isRunning else { return }
        isRunning = true
        runningPhase = .setup
        defer {
            isRunning = false
            runningPhase = nil
            runningStep = nil
            moduleDownload = nil
        }
        beginModuleDownload(title: project.name, status: "Retrying packages…")
        let directory = GoPackageGraph.directory(of: project.entryFile)
        let pattern = directory.isEmpty ? "." : "./\(directory)"
        let vendored = await addingMissingModules(to: project, phase: .build, pattern: pattern)
        if vendored.files != project.files {
            replaceFiles(with: vendored.files)
        }
        if packageProblems.isEmpty {
            lastResult = nil
        } else {
            lastResult = .failure(
                phase: .setup,
                detail: packageProblems.map(\.outputLine).joined(separator: "\n")
            )
        }
    }

    /// Vendors modules named in `go.mod` that the selected build imports and
    /// does not yet have. A GitHub project that is missing its own source is
    /// filled from the repository first. Nothing is returned until that work
    /// finishes; a failure leaves the project unopened.
    private func addingMissingModules(
        to project: GopherForgeProject,
        phase: CompilationResult.Phase,
        pattern: String
    ) async -> GopherForgeProject {
        guard phase != .format, phase != .setup else { return project }
        guard GoModParser.parse(project.files["go.mod"] ?? "") != nil else { return project }
        if toolchain == .missing {
            toolchain = compiler.probe()
        }

        var project = project
        var restoredSource = false
        packageProblems = []
        while true {
            let preparer = GoDependencyPreparer(
                maximumModules: 160,
                planError: { [compiler] files, skipping in
                    let snapshot = GoSourceSnapshot(
                        files: files,
                        packagePattern: pattern,
                        entryFile: project.entryFile
                    )
                    let missing = compiler.missingImportPaths(phase: phase, project: snapshot)
                    guard let parsed = GoModParser.parse(files["go.mod"] ?? "") else {
                        return missing.first.map { .unresolvedImport($0, importedBy: project.entryFile) }
                    }
                    let ordered = missing.sorted { lhs, rhs in
                        let lhsExternal = Self.isDownloadable(lhs, module: parsed, skipping: skipping)
                        let rhsExternal = Self.isDownloadable(rhs, module: parsed, skipping: skipping)
                        if lhsExternal != rhsExternal { return lhsExternal }
                        return lhs < rhs
                    }
                    for path in ordered {
                        if case let .success(resolved) = GoRequirementMatch.resolve(
                            importPath: path, module: parsed
                        ), skipping.contains(resolved.path) {
                            continue
                        }
                        return .unresolvedImport(path, importedBy: parsed.modulePath)
                    }
                    return nil
                },
                install: { path, version, files in
                    if self.moduleDownloadCancelled { throw CancellationError() }
                    self.noteDownload("Adding \(path)…", module: path)
                    let task = Task { try await GoPackageInstaller().install(
                        path: path,
                        version: version,
                        into: files
                    ) }
                    self.currentModuleTask = task
                    let result: GoPackageInstaller.Result
                    do {
                        result = try await task.value
                    } catch {
                        if self.currentModuleTask == task { self.currentModuleTask = nil }
                        throw error
                    }
                    if self.currentModuleTask == task { self.currentModuleTask = nil }
                    self.persistDownloaded(result.files)
                    return result.files
                },
                shouldStop: { self.moduleDownloadCancelled }
            )
            do {
                let prepared = try await preparer.prepare(files: project.files)
                packageProblems.append(contentsOf: prepared.problems)
                return project.replacingFiles(prepared.files)
            } catch let failure as GoDependencyPreparer.Failure {
                if case .missingFromProject = failure, !restoredSource,
                   let restored = try? await restoringRepositorySource(
                    of: project.replacingFiles(failure.files)
                   ), restored.files != project.files {
                    restoredSource = true
                    project = restored
                    continue
                }
                packageProblems.append(Self.problem(from: failure))
                return project.replacingFiles(failure.files)
            } catch {
                packageProblems.append(
                    PackageDownloadProblem(
                        module: project.name,
                        reason: .notLoaded,
                        detail: error.localizedDescription
                    )
                )
                return project
            }
        }
    }

    /// True when Run has to fetch something before the compiler can start.
    private func needsModuleDownload(
        _ project: GopherForgeProject,
        phase: CompilationResult.Phase,
        pattern: String
    ) -> Bool {
        guard let module = GoModParser.parse(project.files["go.mod"] ?? "") else { return false }
        if toolchain == .missing { toolchain = compiler.probe() }
        guard let error = compiler.graphError(
            phase: phase,
            project: GoSourceSnapshot(
                files: project.files,
                packagePattern: pattern,
                entryFile: project.entryFile
            )
        ), case let .unresolvedImport(importPath, _) = error else { return false }
        switch GoRequirementMatch.resolve(importPath: importPath, module: module) {
        case .success: return true
        case .failure(.missingFromProject): return githubReference(of: project) != nil
        default: return false
        }
    }

    /// Downloads the GitHub snapshot again and copies in Go files this project
    /// does not have. An earlier import stopped at a line budget and left out
    /// packages the program still imports, such as `server/fileserver`.
    private func restoringRepositorySource(of project: GopherForgeProject) async throws -> GopherForgeProject? {
        guard let reference = githubReference(of: project) else { return nil }
        noteDownload("Loading repository source…")
        let fresh = try await GitHubRepositoryImporter().importRepository(reference)
        let merged = GitHubRepositoryImporter.mergingMissingSource(into: project.files, from: fresh.files)
        return project.replacingFiles(merged)
    }

    private func githubReference(of project: GopherForgeProject) -> GitHubRepositoryReference? {
        guard project.provenance?.source == .github,
              let owner = project.provenance?.owner,
              let repository = project.provenance?.repository,
              !owner.isEmpty, !repository.isEmpty
        else { return nil }
        return GitHubRepositoryReference(
            owner: owner,
            repository: repository,
            reference: project.provenance?.reference
        )
    }

    private func beginModuleDownload(title: String, status: String) {
        moduleDownload = ModuleDownload(title: title, status: status, installed: [], failure: nil)
    }

    private func noteDownload(_ status: String, module: String? = nil) {
        runningStep = GoBuildProgress(label: status, step: 1, totalSteps: 1)
        if let module, module != moduleAttemptName {
            moduleAttemptName = module
            moduleAttemptStarted = Date()
        }
        guard moduleDownload != nil else { return }
        moduleDownload?.status = status
        if let module, moduleDownload?.installed.contains(module) == false {
            moduleDownload?.installed.append(module)
        }
    }

    /// Writes each module as it arrives, so closing the window, locking the
    /// phone, or leaving the app does not throw away what already downloaded.
    private func persistDownloaded(_ files: [String: String]) {
        guard project != nil else { return }
        replaceFiles(with: files)
    }

    private static func problem(from failure: GoDependencyPreparer.Failure) -> PackageDownloadProblem {
        switch failure {
        case let .missingFromProject(importPath, _):
            PackageDownloadProblem(
                module: importPath,
                reason: .notLoaded,
                detail: failure.detail
            )
        case let .localReplacement(module, _, _):
            PackageDownloadProblem(
                module: module,
                reason: .unsupportedVersion,
                detail: failure.detail
            )
        case let .installFailed(module, _, _), let .repeated(module, _):
            PackageDownloadProblem(
                module: module,
                reason: .notLoaded,
                detail: failure.detail
            )
        case .tooManyModules:
            PackageDownloadProblem(
                module: "packages",
                reason: .notLoaded,
                detail: failure.detail
            )
        }
    }

    private static func isDownloadable(
        _ importPath: String,
        module: GoModule,
        skipping: Set<String>
    ) -> Bool {
        guard case let .success(resolved) = GoRequirementMatch.resolve(importPath: importPath, module: module)
        else { return false }
        return !skipping.contains(resolved.path)
    }

    private func failModuleDownload(_ message: String) {
        guard moduleDownload != nil else { return }
        moduleDownload?.status = "Couldn't finish"
        moduleDownload?.failure = message
    }

    private func record(
        _ result: CompilationResult,
        phase: CompilationResult.Phase,
        projectID: UUID,
        revision: UInt64? = nil,
        opening: Int? = nil,
        sourceReady: Task<Void, Never>? = nil
    ) async {
        let revision = revision ?? sourceRevision
        let opening = opening ?? projectGeneration
        if self.projectID == projectID, sourceRevision == revision, projectGeneration == opening {
            lastResult = result
            resultGeneration += 1
            clearFocusedError()
            refreshSitePreview()
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
        try? await progress.recordMistakes(conceptTags: result.diagnostics.compactMap(\.conceptTag))
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
        removePackages([modulePath])
    }

    /// Drops several modules in one write. Used when a package's dependencies
    /// are not imported by anything that will remain.
    func removePackages(_ modulePaths: [String]) {
        guard var files = project?.files else { return }
        for path in modulePaths {
            files = GoVendorWriter.remove(modulePath: path, from: files)
        }
        replaceFiles(with: files)
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
        refreshSitePreview()
    }

    /// One atomic source change for rename/delete, including the entry point
    /// and the selected buffer. Saving must see the same paths as the editor.
    func applyFileChange(_ files: [String: String], entryFile: String?, selectedFile: String) {
        guard let project, let entryFile else { return }
        self.project = GopherForgeProject(
            name: project.name, files: files, entryFile: entryFile, provenance: project.provenance
        )
        self.selectedFile = selectedFile
        editorText = files[selectedFile] ?? ""
        highlightQuery = ""
        clearFocusedError()
        sourceRevision &+= 1
        hasUnsavedChanges = true
        refreshIdioms()
        scheduleAutosave()
        refreshSitePreview()
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
