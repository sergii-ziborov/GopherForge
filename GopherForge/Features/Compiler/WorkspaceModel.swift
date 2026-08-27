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
    private(set) var lastResult: CompilationResult?
    private(set) var idiomFindings: [IdiomFinding] = []
    private(set) var isRunning = false
    private(set) var runningPhase: CompilationResult.Phase?
    /// What the toolchain is doing right now, or nil between runs. A build on a
    /// phone takes seconds, and a spinner that says nothing for that long reads
    /// as a button that does not work.
    private(set) var runningStep: GoBuildProgress?

    var selectedFile: String = "main.go"
    var editorText: String = ""

    private let compiler: WasmGoCompiler
    private let analyzer: IdiomAnalyzer
    private let library: ProjectLibrary
    private let progress: LearningProgressStore
    private var compileAttempts = 0

    init(
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        library: ProjectLibrary = ProjectLibrary(),
        progress: LearningProgressStore = LearningProgressStore()
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

    func prepare() async {
        toolchain = compiler.probe()
        if project == nil {
            open(ProjectTemplate.commandLineTool.project(named: "Playground"))
        }
    }

    func open(_ project: GopherForgeProject) {
        self.project = project
        selectedFile = project.entryFile
        editorText = project.files[project.entryFile] ?? ""
        lastResult = nil
        compileAttempts = 0
        refreshIdioms()
    }

    func select(file: String) {
        commitEditorText()
        selectedFile = file
        editorText = project?.files[file] ?? ""
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
        refreshIdioms()
    }

    func run(_ phase: CompilationResult.Phase) async {
        commitEditorText()
        guard let project, !isRunning else { return }

        isRunning = true
        runningPhase = phase
        defer {
            isRunning = false
            runningPhase = nil
            runningStep = nil
        }

        let snapshot = project.snapshot(packagePattern: phase == .run ? "." : "./...")
        let result = await execute(phase: phase, snapshot: snapshot)
        lastResult = result
        compileAttempts += 1

        if phase == .format, result.succeeded {
            // gofmt rewrites files in place; the editor must show what the
            // toolchain produced rather than what the user typed.
            apply(formattedFiles: result.formattedFiles)
        }

        try? await library.record(
            project: project,
            lastBuild: ProjectBuildRecord(result: result)
        )
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
        if files[selectedFile] == nil {
            selectedFile = updated.entryFile
        }
        editorText = files[selectedFile] ?? ""
        refreshIdioms()
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
        snapshot: GoSourceSnapshot
    ) async -> CompilationResult {
        // The compiler reports from its own queue and must stay unaware that a
        // main actor exists, so the hop happens here, once, for every phase.
        let report: GoBuildProgressHandler = { [weak self] progress in
            Task { @MainActor in self?.runningStep = progress }
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
        if let reformatted = files[selectedFile] { editorText = reformatted }
        refreshIdioms()
    }

    private func refreshIdioms() {
        guard let project else {
            idiomFindings = []
            return
        }
        idiomFindings = analyzer.analyze(project.snapshot())
    }
}
