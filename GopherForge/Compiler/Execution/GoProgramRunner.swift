import Foundation
import WasmKit

/// Runs a compiled guest program under the user-program sandbox.
///
/// The program gets tighter limits than the toolchain and exactly one writable
/// directory. Nothing about the build environment is reachable from it.
struct GoProgramRunner {
    private let job: GoWorkspaceStager.Layout

    init(job: GoWorkspaceStager.Layout) {
        self.job = job
    }

    func run(
        module: Module,
        diagnostics: [GoDiagnostic],
        started: ContinuousClock.Instant,
        clock: ContinuousClock,
        successDetail: String
    ) throws -> CompilationResult {
        let runner = WasiProcessRunner(captureDirectory: job.jobRoot, capturePrefix: "program")
        let invocation = WasiProcessRunner.Invocation(
            arguments: GoToolInvocation.programArguments(),
            preopens: [WasmSandboxPolicy.writableGuestDirectory: job.sandbox.path],
            memoryLimitBytes: WasmSandboxPolicy.userProgramMemoryLimitBytes,
            tableElementLimit: WasmSandboxPolicy.userProgramTableElementLimit
        )

        do {
            let (exitCode, output) = try runner.run(module: module, invocation: invocation)
            return CompilationResult(
                succeeded: exitCode == 0,
                phase: .run,
                exitCode: exitCode,
                diagnostics: diagnostics,
                stdout: output.stdout,
                stderr: output.stderr,
                duration: started.duration(to: clock.now),
                detail: exitCode == 0 ? successDetail : "The program exited with code \(exitCode)."
            )
        } catch let failure as WasiProcessRunner.RunFailure {
            return result(for: failure, diagnostics: diagnostics, started: started, clock: clock)
        }
    }

    private func result(
        for failure: WasiProcessRunner.RunFailure,
        diagnostics: [GoDiagnostic],
        started: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> CompilationResult {
        let output: WasiProcessRunner.Output
        let detail: String

        switch failure {
        case let .limitExceeded(resource, captured):
            output = captured
            detail = switch resource {
            case .memory:
                "Program stopped at the \(WasmSandboxPolicy.memoryLimitLabel) sandbox memory limit."
            case .table:
                "Program stopped at the sandbox table limit."
            }
        case let .trapped(error, captured):
            output = captured
            // A Go runtime panic and a deadlock both arrive here, and both are
            // teachable rather than internal errors, so the guest's own stderr
            // leads the message.
            detail = GoRuntimeFailureReader.describe(stderr: captured.stderr)
                ?? "The program stopped: \(error)"
        }

        return CompilationResult(
            succeeded: false,
            phase: .run,
            exitCode: nil,
            diagnostics: diagnostics + GoRuntimeFailureReader.diagnostics(stderr: output.stderr),
            stdout: output.stdout,
            stderr: output.stderr,
            duration: started.duration(to: clock.now),
            detail: detail
        )
    }
}
