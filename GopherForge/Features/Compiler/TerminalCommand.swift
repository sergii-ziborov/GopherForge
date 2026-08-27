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
    case unknown(String)

    static func parse(_ input: String) -> TerminalCommand {
        let fields = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let head = fields.first else { return .unknown("") }
        let rest = Array(fields.dropFirst())

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

      go build      type-check and link the module
      go run        build and run the main package
      go test       run the package tests
      go vet        report suspicious constructs
      go fmt        format with the bundled gofmt
      go mod        show the parsed module
      ls [dir]      list project files
      cat <file>    print a project file
      pwd           print the module root
      clear         clear this transcript
    """
}
