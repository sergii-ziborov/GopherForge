import Foundation
import Observation

/// The project console: a transcript and the commands that produced it.
///
/// It keeps its own history per project and runs everything through the same
/// workspace operations the buttons use, so the console can never do something
/// the UI cannot, and never reports success the UI would call failure.
@MainActor
@Observable
final class ProjectTerminalSession {
    struct Entry: Identifiable {
        enum Kind {
            case command
            case output
            case failure
        }

        let id = UUID()
        let kind: Kind
        let text: String
        /// Set when the entry is the contents of a file, so the console can
        /// highlight it with the same tokenizer the editor uses instead of
        /// printing Go as grey text.
        var language: SourceFileKind?
    }

    private(set) var transcript: [Entry] = []
    private(set) var isBusy = false
    private(set) var frontendFailure: String?
    var input = ""

    private let maximumEntries = 200
    private unowned let workspace: WorkspaceModel
    private let frontend = OfflineFrontendBuilder()

    init(workspace: WorkspaceModel) {
        self.workspace = workspace
        append(.output, TerminalCommand.helpText)
    }

    func submit() async {
        let line = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !isBusy else { return }
        input = ""
        append(.command, "$ \(line)")

        isBusy = true
        defer { isBusy = false }
        await run(TerminalCommand.parse(line))
    }

    private func run(_ command: TerminalCommand) async {
        switch command {
        case .clear:
            transcript.removeAll()
        case .help:
            append(.output, TerminalCommand.helpText)
        case .printWorkingDirectory:
            append(.output, workspace.project?.module?.modulePath ?? "no module open")
        case let .list(directory):
            append(.output, listing(in: directory))
        case let .show(path):
            show(path)
        case .modules:
            showModule()
        case let .frontend(command):
            await runFrontend(command)
        case let .unavailableRuntime(tool):
            append(.failure, """
                \(tool) is not installed in GopherForge. This console provides \
                an educational offline frontend subset, without full JavaScript \
                runtimes. It supports frontend install/build/preview \
                and compatible npm spellings. Type help for its limits.
                """)
        case let .unknown(text):
            append(.failure, unknownMessage(for: text))
        case let .unsupported(message):
            append(.failure, message)
        case .build, .run, .test, .vet, .format:
            await runPhase(command)
        }
    }

    /// The Output action uses exactly the terminal's bounded offline pipeline.
    func buildPreview() async {
        guard !isBusy, !workspace.isRunning, !workspace.debugger.isActive else { return }
        isBusy = true
        defer { isBusy = false }
        let generation = workspace.projectGeneration
        append(.command, "$ frontend install")
        guard await runFrontend(.install(frozen: false)) else { return }
        guard workspace.projectGeneration == generation else {
            frontendFailure = "The project changed. Build its preview from Output again."
            append(.failure, frontendFailure!)
            return
        }
        append(.command, "$ frontend build")
        _ = await runFrontend(.build(packageScript: false))
    }

    @discardableResult
    private func runFrontend(_ command: OfflineFrontendCommand) async -> Bool {
        frontendFailure = nil
        do {
            if command == .capabilities { append(.output, OfflineFrontendCommand.capabilitiesText); return true }
            if command == .packages {
                append(.output, "Bundled offline packages (no registry access):\n" + (try await frontend.packageSummary()))
                return true
            }
            workspace.commitEditorText()
            guard !workspace.debugger.isActive else { throw OfflineFrontendError.message("Stop the source debugger before changing the frontend build.") }
            guard let snapshot = workspace.project?.files else { throw OfflineFrontendError.message("Open a frontend project first.") }
            let generation = workspace.projectGeneration
            let revision = workspace.sourceRevision
            try command.validateScript(in: snapshot)
            switch command {
            case let .install(frozen):
                let plan = try await frontend.plan(files: snapshot)
                workspace.commitEditorText()
                guard workspace.projectGeneration == generation, workspace.sourceRevision == revision else { throw OfflineFrontendError.message("The project changed. Run install again.") }
                if frozen, snapshot[OfflineFrontendRecipe.lockPath] != plan.lock {
                    throw OfflineFrontendError.message("The offline lock is missing or stale. Run frontend install first.")
                }
                var files = snapshot
                files[OfflineFrontendRecipe.lockPath] = plan.lock
                workspace.replaceFiles(with: files)
                append(.output, "Offline frontend lock ready. Packages are staged from the bundled catalog at build time; no scripts or downloads run.\n" + plan.packages.map { "\($0.name)@\($0.version)" }.joined(separator: "\n"))
            case .build:
                append(.output, "Building locally in WASI. No network, shell, project plugins or lifecycle hooks.")
                let result = try await frontend.build(files: snapshot)
                workspace.commitEditorText()
                guard workspace.projectGeneration == generation, workspace.sourceRevision == revision else { throw OfflineFrontendError.message("Source changed during bundling; the result was discarded. Build again.") }
                var files = snapshot.filter { !$0.key.hasPrefix(result.outputDirectory + "/") }
                files.merge(result.generated) { _, generated in generated }
                workspace.replaceFiles(with: files)
                append(.output, result.stdout)
                append(.output, "Offline preview ready in Output. This is a browser build, not a Node.js server or a TypeScript type check.")
            case .preview:
                guard OfflineFrontendPlan.previewReady(files: snapshot) else { throw OfflineFrontendError.message("Run frontend build first; generated assets are missing or source changed.") }
                workspace.refreshSitePreview()
                append(.output, "Isolated offline preview is ready in Output. External networking is blocked; preview storage is temporary.")
            case .packages, .capabilities: break
            }
            return true
        } catch {
            frontendFailure = error.localizedDescription
            append(.failure, error.localizedDescription)
            return false
        }
    }

    private func runPhase(_ command: TerminalCommand) async {
        guard let phase = command.phase else { return }
        guard workspace.toolchain.isReady else {
            append(.failure, "\(workspace.toolchain.label). \(workspace.toolchain.detail)")
            return
        }

        await workspace.run(phase)
        guard let result = workspace.lastResult else { return }

        append(result.succeeded ? .output : .failure, result.detail)
        for diagnostic in result.diagnostics {
            append(diagnostic.isBlocking ? .failure : .output, diagnostic.rendered)
        }
        if !result.stdout.isEmpty { append(.output, result.stdout) }
        for test in result.tests {
            let mark = test.outcome == .passed ? "ok" : test.outcome.rawValue
            append(test.outcome == .failed ? .failure : .output, "\(mark)\t\(test.name)")
        }
    }

    private func listing(in directory: String?) -> String {
        guard let project = workspace.project else { return "no project open" }
        let prefix = directory.map { $0.hasSuffix("/") ? $0 : $0 + "/" } ?? ""
        let paths = project.files.keys
            .filter { prefix.isEmpty || $0.hasPrefix(prefix) }
            .sorted()
        return paths.isEmpty ? "nothing at \(directory ?? ".")" : paths.joined(separator: "\n")
    }

    private func show(_ path: String) {
        guard let contents = workspace.project?.files[path] else {
            append(.failure, "no such file: \(path)")
            return
        }
        append(.output, contents, language: SourceFileKind.of(path: path))
    }

    private func showModule() {
        guard let module = workspace.project?.module else {
            append(.failure, "no go.mod in this project")
            return
        }
        var lines = ["module \(module.modulePath)"]
        if let version = module.goVersion { lines.append("go \(version)") }
        lines.append("requirements: \(module.requirements.count)")
        for requirement in module.requirements {
            lines.append("\t\(requirement.path) \(requirement.version)"
                + (requirement.isIndirect ? " // indirect" : ""))
        }
        append(.output, lines.joined(separator: "\n"))
    }

    private func unknownMessage(for text: String) -> String {
        text.isEmpty
            ? "type help to see what this console understands"
            : "\(text): not something this console runs. Type help."
    }

    private func append(_ kind: Entry.Kind, _ text: String, language: SourceFileKind? = nil) {
        guard !text.isEmpty else { return }
        transcript.append(Entry(kind: kind, text: text, language: language))
        if transcript.count > maximumEntries {
            transcript.removeFirst(transcript.count - maximumEntries)
        }
    }
}
