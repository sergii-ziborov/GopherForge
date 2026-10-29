import Foundation

/// One command the project console understands.
///
/// This is an app-scoped console, not a shell. Every command maps to an
/// operation the app already performs, so nothing here can reach outside the
/// project or the sandbox — and an unknown command says so rather than being
/// forwarded anywhere.
enum TerminalCommand: Equatable {
    case build
    case run
    case test
    case vet
    case format
    case modules
    case list(String?)
    case show(String)
    case printWorkingDirectory
    case clear
    case help
    case frontend(OfflineFrontendCommand)
    case unavailableRuntime(String)
    case unsupported(String)
    case unknown(String)

    static func parse(_ input: String) -> TerminalCommand {
        let line = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.contains(where: { "\n\r\"'`;$|&<>".contains($0) }) else {
            return .unsupported("Shell syntax and quoted arguments are not supported. Nothing was run.")
        }
        let fields = line
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard let head = fields.first else { return .unknown("") }
        let rest = Array(fields.dropFirst())
        if let command = OfflineFrontendCommand.parse(fields) { return .frontend(command) }

        if head == "go", rest.count != 1 {
            if rest.contains("-race") {
                return .unsupported("The WASI toolchain has no race detector. Tests were not run.")
            }
            return .unsupported("Go flags, package targets, program arguments and mod subcommands are not supported here. Nothing was run. Use an exact command from help; Run/Build use the target selected in the editor.")
        }
        if ["gofmt", "pwd", "clear", "help"].contains(head), !rest.isEmpty {
            return .unsupported("\(head) accepts no arguments in this console. Nothing was run.")
        }
        if ["ls", "cat"].contains(head), rest.count > 1 {
            return .unsupported("\(head) accepts one literal project path. Nothing was run.")
        }

        switch (head, rest.first) {
        case ("go", "build"): return .build
        case ("go", "run"): return .run
        case ("go", "test"): return .test
        case ("go", "vet"): return .vet
        case ("go", "fmt"): return .format
        case ("go", "mod"): return .modules
        case ("gofmt", _): return .format
        case ("ls", _): return .list(rest.first)
        case ("cat", _):
            guard let path = rest.first else { return .unknown("cat needs a file") }
            return .show(path)
        case ("pwd", _): return .printWorkingDirectory
        case ("clear", _): return .clear
        case ("help", _): return .help
        case ("node", _), ("npm", _), ("npx", _), ("bun", _), ("bunx", _):
            return .unavailableRuntime(head)
        default: return .unknown(input.trimmingCharacters(in: .whitespaces))
        }
    }

    /// The phase this command runs, when it runs one.
    var phase: CompilationResult.Phase? {
        switch self {
        case .build: .build
        case .run: .run
        case .test: .test
        case .vet: .vet
        case .format: .format
        default: nil
        }
    }

    static let helpText = """
    This console runs GopherForge's own operations, not a shell.

      go build      build the target selected in the editor
      go run        build and run that selected target
      go test       run all project package tests
      go vet        report suspicious constructs
      go fmt        format with the bundled gofmt
      go mod        show the parsed module
      ls [dir]      list project files
      cat <file>    print a project file
      pwd           print the module root
      clear         clear this transcript

    Only these exact Go command forms are supported. Flags, explicit targets,
    program arguments, go mod subcommands, quotes and shell syntax are rejected.
    go mod displays metadata; it does not perform tidy or dependency changes.

      frontend packages   list bundled browser packages
      frontend install    prepare the offline frontend lock
      frontend build      bundle JS/TS/JSX with the WASI tool
      frontend preview    check the isolated preview is ready

    npm install --offline / npm run build are compatible spellings for this
    educational offline mode. Full Node.js/npm runtimes and arbitrary package
    scripts are not included.
    """
}
