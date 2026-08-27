import Foundation
import WasmKit

/// Runs a build plan: one WASI invocation per step, in order, stopping at the
/// first failure.
///
/// The session owns no policy. What to build and in what order is the
/// planner's; how to sandbox an invocation is the runner's. This type only
/// materialises each step's generated files, runs it, and turns what the tools
/// wrote into something the UI can show.
struct GoToolSession {
    struct Outcome {
        let succeeded: Bool
        let exitCode: UInt32?
        let diagnostics: [GoDiagnostic]
        let output: WasiProcessRunner.Output
        let tests: [GoTestResult]
        /// Files gofmt rewrote, project-relative, so the editor can show what
        /// the formatter produced.
        var formattedFiles: [String: String] = [:]
        /// The step that failed, for a message that names it.
        var failedStep: String?
        /// Steps satisfied from a previous build rather than run again.
        var reusedSteps: [String] = []

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
                tests: tests,
                formattedFiles: formattedFiles,
                reusedSteps: reusedSteps.count
            )
        }

        private func detail(for phase: CompilationResult.Phase) -> String {
            if let first = diagnostics.first(where: \.isBlocking) { return first.message }
            if succeeded {
                return switch phase {
                case .build:
                    reusedSteps.isEmpty
                        ? "The real bundled toolchain accepted the package."
                        : "Accepted. \(reusedSteps.count) package\(reusedSteps.count == 1 ? "" : "s") "
                            + "were unchanged and reused."
                case .vet: "go vet found nothing to report."
                case .format:
                    formattedFiles.isEmpty
                        ? "Every file was already gofmt-clean."
                        : "gofmt rewrote \(formattedFiles.count) file\(formattedFiles.count == 1 ? "" : "s")."
                case .test: "\(tests.passedCount) of \(tests.count) tests passed."
                default: "Completed."
                }
            }
            if phase == .test, tests.failedCount > 0 {
                return "\(tests.failedCount) of \(tests.count) tests failed."
            }
            if let failedStep {
                return "Failed at \(failedStep) (exit \(exitCode.map(String.init) ?? "trap"))."
            }
            return "The toolchain exited with code \(exitCode.map(String.init) ?? "unknown")."
        }
    }

    /// Resolves and parses a tool's module. Kept as a closure so the compiler
    /// can cache modules across jobs without this type knowing how.
    let module: (GoToolStep.Tool) throws -> Module
    let layout: GoToolchainLocator.Layout
    let job: GoWorkspaceStager.Layout
    let sources: GoSourceSnapshot
    let goVersion: String
    /// Compiled archives kept between builds, so an unchanged package is not
    /// compiled again.
    let artifacts: GoStepArtifactCache?
    /// Called as each step begins, from the queue the build runs on.
    var onProgress: GoBuildProgressHandler = { _ in }
    /// Steps that were satisfied from the cache rather than run. Reported so a
    /// claim about incremental builds can be checked rather than believed.
    private(set) var reusedStepLabels: [String] = []

    enum SessionError: Error, Equatable {
        case unresolvableGuestPath(String)
        case toolNotBundled(String)
    }

    mutating func run(plan: GoBuildPlan, phase: CompilationResult.Phase) throws -> Outcome {
        var diagnostics: [GoDiagnostic] = []
        var stdout = ""
        var stderr = ""

        for (index, step) in plan.steps.enumerated() {
            onProgress(
                GoBuildProgress(label: step.label, step: index + 1, totalSteps: plan.steps.count)
            )
            if try reuseCachedArtifact(for: step) { continue }
            try write(step.generatedFiles)
            let (exitCode, output) = try invoke(step: step, phase: phase)
            let reported = step.tool.writesDiagnosticsToStandardOutput
                ? output.stdout + output.stderr
                : output.stderr
            // A tool's stdout is never the user's program output — that comes
            // from running what was linked — so it is only kept where it
            // carries something the caller needs, which is gofmt's file list.
            if step.tool == .format { stdout += output.stdout }
            stderr += reported
            diagnostics += GoDiagnosticParser.parse(
                stderr: reported,
                origin: step.tool == .vet ? .vet : .compiler,
                sourceLines: sources.sourceLines
            )

            if exitCode == 0 { rememberArtifact(of: step) }

            guard exitCode == 0, !diagnostics.contains(where: \.isBlocking) else {
                return Outcome(
                    succeeded: false,
                    exitCode: exitCode,
                    diagnostics: diagnostics,
                    output: WasiProcessRunner.Output(stdout: stdout, stderr: stderr),
                    tests: [],
                    failedStep: step.label,
                    reusedSteps: reusedStepLabels
                )
            }
        }

        return try finish(plan: plan, phase: phase, diagnostics: diagnostics, stdout: stdout, stderr: stderr)
    }

    // MARK: - Steps

    private func invoke(
        step: GoToolStep,
        phase: CompilationResult.Phase
    ) throws -> (UInt32, WasiProcessRunner.Output) {
        guard layout.module(for: step.tool) != nil else {
            throw SessionError.toolNotBundled(step.tool.rawValue)
        }

        let runner = WasiProcessRunner(captureDirectory: job.jobRoot, capturePrefix: step.tool.rawValue)
        let invocation = WasiProcessRunner.Invocation(
            arguments: step.arguments,
            environment: GoToolInvocation.environment(goVersion: goVersion),
            preopens: [
                GoGuestPath.work: job.work.path,
                GoGuestPath.temp: job.temp.path,
                GoGuestPath.cache: job.cache.path,
                GoGuestPath.goroot: layout.goroot.path,
            ],
            memoryLimitBytes: WasmSandboxPolicy.toolchainMemoryLimitBytes,
            tableElementLimit: WasmSandboxPolicy.toolchainTableElementLimit
        )

        do {
            return try runner.run(module: try module(step.tool), invocation: invocation)
        } catch let failure as WasiProcessRunner.RunFailure {
            return try recover(from: failure, step: step, phase: phase)
        }
    }

    /// A trap that still produced diagnostics is a compile failure the user can
    /// act on, not an interpreter error; only a trap with nothing to show is
    /// reported as a toolchain fault.
    private func recover(
        from failure: WasiProcessRunner.RunFailure,
        step: GoToolStep,
        phase: CompilationResult.Phase
    ) throws -> (UInt32, WasiProcessRunner.Output) {
        switch failure {
        case let .limitExceeded(resource, captured):
            // The guest is denied before it runs, so it writes nothing. Saying
            // so here is the difference between a limit the user can read about
            // and a build that fails in silence.
            let note = "\(step.label): the sandbox denied more \(resource.rawValue) "
                + "than the toolchain is allowed.\n"
            return (1, WasiProcessRunner.Output(
                stdout: captured.stdout,
                stderr: captured.stderr + note
            ))
        case let .trapped(error, captured):
            let parsed = GoDiagnosticParser.parse(
                stderr: captured.stdout + captured.stderr,
                origin: phase == .vet ? .vet : .compiler,
                sourceLines: sources.sourceLines
            )
            if parsed.isEmpty { throw error }
            return (1, captured)
        }
    }

    /// Puts a previously built archive where this step would have written it,
    /// and reports whether that happened.
    ///
    /// Nothing else in the build knows the difference: the next step reads the
    /// same path it always reads, and its own key already accounts for this
    /// package's contents.
    private mutating func reuseCachedArtifact(for step: GoToolStep) throws -> Bool {
        guard let key = step.cacheKey,
              let output = step.outputPath,
              let data = artifacts?.archive(for: key),
              let url = job.hostURL(forGuestPath: output)
        else {
            return false
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        reusedStepLabels.append(step.label)
        return true
    }

    /// Remembers what a step produced, so the next build can skip it.
    private func rememberArtifact(of step: GoToolStep) {
        guard let key = step.cacheKey,
              let output = step.outputPath,
              let url = job.hostURL(forGuestPath: output),
              let data = try? Data(contentsOf: url)
        else {
            return
        }
        artifacts?.store(data, for: key)
    }

    private func write(_ files: [String: String]) throws {
        for (guestPath, contents) in files.sorted(by: { $0.key < $1.key }) {
            guard let url = job.hostURL(forGuestPath: guestPath) else {
                throw SessionError.unresolvableGuestPath(guestPath)
            }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: url, options: .atomic)
        }
    }

    // MARK: - Results

    private func finish(
        plan: GoBuildPlan,
        phase: CompilationResult.Phase,
        diagnostics: [GoDiagnostic],
        stdout: String,
        stderr: String
    ) throws -> Outcome {
        var outcome = Outcome(
            succeeded: true,
            exitCode: 0,
            diagnostics: diagnostics,
            output: WasiProcessRunner.Output(stdout: stdout, stderr: stderr),
            tests: [],
            reusedSteps: reusedStepLabels
        )

        if phase == .format {
            outcome.formattedFiles = readFormattedFiles(listedIn: stdout)
        }

        return outcome
    }

    /// `gofmt -l -w` prints the files it rewrote. Reading only those back keeps
    /// an untouched buffer untouched, so formatting never disturbs a file it
    /// had no changes for.
    private func readFormattedFiles(listedIn stdout: String) -> [String: String] {
        var formatted: [String: String] = [:]
        for line in stdout.split(separator: "\n") {
            let guestPath = String(line).trimmingCharacters(in: .whitespaces)
            guard !guestPath.isEmpty,
                  let url = job.hostURL(forGuestPath: guestPath),
                  let data = try? Data(contentsOf: url)
            else {
                continue
            }
            let relative = ProjectPathNormalizer.normalize(guestPath)
            guard sources.files[relative] != nil else { continue }
            formatted[relative] = String(decoding: data, as: UTF8.self)
        }
        return formatted
    }
}
