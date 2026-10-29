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
        successDetail: String,
        runtimeRequest: String? = nil,
        debugControl: GoDebugControl? = nil
    ) throws -> CompilationResult {
        let runner = WasiProcessRunner()
        let invocation = WasiProcessRunner.Invocation(
            arguments: GoToolInvocation.programArguments(),
            preopens: [WasmSandboxPolicy.writableGuestDirectory: job.sandbox.path],
            memoryLimitBytes: WasmSandboxPolicy.userProgramMemoryLimitBytes,
            tableElementLimit: WasmSandboxPolicy.userProgramTableElementLimit,
            outputLimitBytes: WasmSandboxPolicy.userProgramOutputLimitBytes,
            debugControl: debugControl
        )

        do {
            if let runtimeRequest {
                guard runtimeRequest.utf8.count <= 2 * 1024 * 1024 else {
                    throw OfflineFrontendError.message("Offline API request history exceeds 2 MiB.")
                }
                try Data(runtimeRequest.utf8).write(to: job.sandbox.appending(path: ".gopherforge-http.json"))
            }
            let (exitCode, output) = try runner.run(module: module, invocation: invocation)
            // Before the caller removes the job: a program that drew something
            // has already written it, and the directory is about to go.
            let artifacts = GoProgramArtifacts.collect(from: job.sandbox)
            return CompilationResult(
                succeeded: exitCode == 0,
                phase: .run,
                exitCode: exitCode,
                diagnostics: diagnostics,
                stdout: output.stdout,
                stderr: output.stderr,
                duration: started.duration(to: clock.now),
                detail: exitCode == 0
                    ? detail(for: artifacts, otherwise: successDetail)
                    : "The program exited with code \(exitCode).",
                artifacts: artifacts,
                sandboxResponse: runtimeRequest == nil ? nil : readResponse()
            )
        } catch let failure as WasiProcessRunner.RunFailure {
            return result(for: failure, diagnostics: diagnostics, started: started, clock: clock)
        }
    }

    private func readResponse() -> String? {
        let url = job.sandbox.appending(path: ".gopherforge-response.json")
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true, let size = values.fileSize, size <= 512 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func detail(for artifacts: GoProgramArtifacts, otherwise fallback: String) -> String {
        guard !artifacts.isEmpty else { return fallback }
        let count = artifacts.images.count
        return "Ran, and drew \(count) image\(count == 1 ? "" : "s")."
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
