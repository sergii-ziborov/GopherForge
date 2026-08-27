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
    }

    private(set) var transcript: [Entry] = []
    private(set) var isBusy = false
    var input = ""

    private let maximumEntries = 200
    private unowned let workspace: WorkspaceModel

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
        case let .unknown(text):
            append(.failure, unknownMessage(for: text))
        case .build, .run, .test, .vet, .format:
            await runPhase(command)
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
        append(.output, contents)
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

    private func append(_ kind: Entry.Kind, _ text: String) {
        guard !text.isEmpty else { return }
        transcript.append(Entry(kind: kind, text: text))
        if transcript.count > maximumEntries {
            transcript.removeFirst(transcript.count - maximumEntries)
        }
    }
}
