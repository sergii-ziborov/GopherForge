import Foundation

/// The single result type every toolchain phase returns.
struct CompilationResult: Sendable {
    enum Phase: String, Codable, Sendable {
        case format
        case vet
        case build
        case run
        case test
        case setup
    }

    let succeeded: Bool
    let phase: Phase
    let exitCode: UInt32?
    let diagnostics: [GoDiagnostic]
    let stdout: String
    let stderr: String
    let duration: Duration
    let detail: String
    let tests: [GoTestResult]
    /// What `gofmt` rewrote, project-relative. Empty for every other phase,
    /// and empty for a format run that found nothing to change.
    let formattedFiles: [String: String]
    /// Packages a previous build had already compiled, so this one did not.
    /// Reported rather than kept private: an incremental build that claims to
    /// be one should be able to say how much it skipped.
    let reusedSteps: Int
    /// Images the program wrote into its sandbox, collected before the sandbox
    /// was removed.
    let artifacts: GoProgramArtifacts

    init(
        succeeded: Bool,
        phase: Phase,
        exitCode: UInt32?,
        diagnostics: [GoDiagnostic],
        stdout: String,
        stderr: String,
        duration: Duration,
        detail: String,
        tests: [GoTestResult] = [],
        formattedFiles: [String: String] = [:],
        reusedSteps: Int = 0,
        artifacts: GoProgramArtifacts = .empty
    ) {
        self.succeeded = succeeded
        self.phase = phase
        self.exitCode = exitCode
        self.diagnostics = diagnostics
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.detail = detail
        self.tests = tests
        self.formattedFiles = formattedFiles
        self.reusedSteps = reusedSteps
        self.artifacts = artifacts
    }

    var blockingDiagnostics: [GoDiagnostic] {
        diagnostics.filter(\.isBlocking)
    }

    static func failure(
        phase: Phase,
        detail: String,
        stderr: String = "",
        duration: Duration = .zero
    ) -> CompilationResult {
        CompilationResult(
            succeeded: false,
            phase: phase,
            exitCode: nil,
            diagnostics: [],
            stdout: "",
            stderr: stderr,
            duration: duration,
            detail: detail
        )
    }
}
