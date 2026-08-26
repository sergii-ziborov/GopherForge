import Foundation
import WasmKit

/// One invocation of the bundled toolchain driver for one phase.
struct GoToolSession {
    struct Outcome {
        let succeeded: Bool
        let exitCode: UInt32?
        let diagnostics: [GoDiagnostic]
        let output: WasiProcessRunner.Output
        let tests: [GoTestResult]

        func result(phase: CompilationResult.Phase, duration: Duration) -> CompilationResult {
            CompilationResult(
                succeeded: succeeded,
                phase: phase,
                exitCode: exitCode,
                diagnostics: diagnostics,
                stdout: output.stdout,
                stderr: diagnostics.isEmpty ? output.stderr : "",
                duration: duration,
                detail: detail(for: phase),
                tests: tests
            )
        }

        private func detail(for phase: CompilationResult.Phase) -> String {
            if let first = diagnostics.first(where: \.isBlocking) { return first.message }
            if succeeded {
                return switch phase {
                case .build: "The real bundled toolchain accepted the package."
                case .vet: "go vet found nothing to report."
                case .format: "Formatting applied by the bundled gofmt."
                case .test: "\(tests.passedCount) of \(tests.count) tests passed."
                default: "Completed."
                }
            }
            if phase == .test, tests.failedCount > 0 {
                return "\(tests.failedCount) of \(tests.count) tests failed."
            }
            return "The toolchain exited with code \(exitCode.map(String.init) ?? "unknown")."
        }
    }

    let driver: Module
    let goVersion: String
    let layout: GoToolchainLocator.Layout
    let job: GoWorkspaceStager.Layout
    let sources: GoSourceSnapshot

    func run(phase: CompilationResult.Phase, packagePattern: String) throws -> Outcome {
        let runner = WasiProcessRunner(captureDirectory: job.jobRoot, capturePrefix: "toolchain")
        let invocation = WasiProcessRunner.Invocation(
            arguments: GoToolInvocation.arguments(for: phase, packagePattern: packagePattern),
            environment: GoToolInvocation.environment(goVersion: goVersion),
            preopens: [
                GoToolInvocation.GuestPath.work: job.work.path,
                GoToolInvocation.GuestPath.temp: job.temp.path,
                GoToolInvocation.GuestPath.cache: job.cache.path,
                GoToolInvocation.GuestPath.goroot: layout.goroot.path,
            ],
            memoryLimitBytes: WasmSandboxPolicy.toolchainMemoryLimitBytes
        )

        do {
            let (exitCode, output) = try runner.run(module: driver, invocation: invocation)
            return outcome(phase: phase, exitCode: exitCode, output: output)
        } catch let failure as WasiProcessRunner.RunFailure {
            return try trappedOutcome(phase: phase, failure: failure)
        }
    }

    private func outcome(
        phase: CompilationResult.Phase,
        exitCode: UInt32,
        output: WasiProcessRunner.Output
    ) -> Outcome {
        let diagnostics = GoDiagnosticParser.parse(
            stderr: output.stderr,
            origin: phase == .vet ? .vet : .compiler,
            sourceLines: sources.sourceLines
        )
        let tests = phase == .test ? GoTestOutputParser.parse(stdout: output.stdout) : []
        let blocked = diagnostics.contains(where: \.isBlocking)
        return Outcome(
            succeeded: exitCode == 0 && !blocked,
            exitCode: exitCode,
            diagnostics: diagnostics,
            output: output,
            tests: tests
        )
    }

    /// A trap that still produced diagnostics is a compile failure the user can
    /// act on, not an interpreter error; only a trap with nothing to show is
    /// reported as a toolchain fault.
    private func trappedOutcome(
        phase: CompilationResult.Phase,
        failure: WasiProcessRunner.RunFailure
    ) throws -> Outcome {
        let output: WasiProcessRunner.Output
        switch failure {
        case let .limitExceeded(_, captured): output = captured
        case let .trapped(error, captured):
            output = captured
            let parsed = GoDiagnosticParser.parse(
                stderr: captured.stderr,
                origin: phase == .vet ? .vet : .compiler,
                sourceLines: sources.sourceLines
            )
            if parsed.isEmpty { throw error }
        }

        return Outcome(
            succeeded: false,
            exitCode: nil,
            diagnostics: GoDiagnosticParser.parse(
                stderr: output.stderr,
                origin: phase == .vet ? .vet : .compiler,
                sourceLines: sources.sourceLines
            ),
            output: output,
            tests: []
        )
    }
}
