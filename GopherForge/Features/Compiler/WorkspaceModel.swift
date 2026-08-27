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

    var selectedFile: String = "main.go"
    var editorText: String = ""

    private let compiler: WasmGoCompiler
    private let analyzer: IdiomAnalyzer
    private let library: ProjectLibrary
    private var compileAttempts = 0

    init(
        compiler: WasmGoCompiler = WasmGoCompiler(),
        analyzer: IdiomAnalyzer = IdiomAnalyzer(),
        library: ProjectLibrary = ProjectLibrary()
    ) {
        self.compiler = compiler
        self.analyzer = analyzer
        self.library = library
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
        switch phase {
        case .format: await compiler.format(project: snapshot)
        case .vet: await compiler.vet(project: snapshot)
        case .build: await compiler.build(project: snapshot)
        case .run: await compiler.run(project: snapshot)
        case .test: await compiler.test(project: snapshot)
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
