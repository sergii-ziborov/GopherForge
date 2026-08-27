import Foundation
import WasmKit

/// Executes one planned phase in a fresh sandbox and turns it into a result.
///
/// Everything here happens after the decisions have been made: the plan is
/// fixed, the toolchain is resolved, and what is left is to stage the project,
/// run the steps, and run whatever they linked. Keeping that apart from the
/// planning and the caching is what stops the orchestrator becoming the place
/// where all four concerns meet.
struct GoPhaseRunner {
    let layout: GoToolchainLocator.Layout
    let stager: GoWorkspaceStager
    let clock: ContinuousClock
    let goVersion: String
    /// Resolves and parses a tool's module; the caller owns the cache.
    let module: (GoToolStep.Tool) throws -> Module

    func run(
        _ plan: GoBuildPlan,
        phase: CompilationResult.Phase,
        project: GoSourceSnapshot,
        cache: GoArtifactCache,
        key: String,
        started: ContinuousClock.Instant
    ) -> CompilationResult {
        let job: GoWorkspaceStager.Layout
        do {
            job = try stager.createLayout(named: UUID().uuidString)
            try stager.stage(files: project.files, into: job.work)
        } catch {
            return stagingFailure(error, started: started)
        }
        defer { stager.remove(job) }

        do {
            let session = GoToolSession(
                module: module,
                layout: layout,
                job: job,
                sources: project,
                goVersion: goVersion
            )
            let outcome = try session.run(plan: plan, phase: phase)
            guard outcome.succeeded else {
                return outcome.result(phase: phase, duration: started.duration(to: clock.now))
            }

            return switch phase {
            case .test: testResult(plan: plan, job: job, outcome: outcome, started: started)
            case .run: runResult(plan: plan, job: job, outcome: outcome, cache: cache, key: key, started: started)
            default: accepted(outcome: outcome, phase: phase, cache: cache, key: key, started: started)
            }
        } catch {
            return .failure(
                phase: phase,
                detail: "Native toolchain runtime failed: \(error)",
                duration: started.duration(to: clock.now)
            )
        }
    }

    // MARK: - Shaping

    private func stagingFailure(
        _ error: any Error,
        started: ContinuousClock.Instant
    ) -> CompilationResult {
        if case let GoWorkspaceStager.StagingError.invalidPath(path) = error {
            return .failure(
                phase: .setup,
                detail: "Invalid project path: \(path)",
                duration: started.duration(to: clock.now)
            )
        }
        return .failure(
            phase: .setup,
            detail: "Could not create the compiler sandbox: \(error.localizedDescription)",
            duration: started.duration(to: clock.now)
        )
    }

    private func accepted(
        outcome: GoToolSession.Outcome,
        phase: CompilationResult.Phase,
        cache: GoArtifactCache,
        key: String,
        started: ContinuousClock.Instant
    ) -> CompilationResult {
        cache.rememberAcceptedBuild(for: key)
        return outcome.result(phase: phase, duration: started.duration(to: clock.now))
    }

    private func testResult(
        plan: GoBuildPlan,
        job: GoWorkspaceStager.Layout,
        outcome: GoToolSession.Outcome,
        started: ContinuousClock.Instant
    ) -> CompilationResult {
        guard !plan.products.isEmpty else {
            return CompilationResult(
                succeeded: true,
                phase: .test,
                exitCode: 0,
                diagnostics: outcome.diagnostics,
                stdout: "",
                stderr: "",
                duration: started.duration(to: clock.now),
                detail: "No test files in this project yet."
            )
        }

        let report = GoTestBinaryRunner(job: job).run(products: plan.products)
        return CompilationResult(
            succeeded: report.allPassed,
            phase: .test,
            exitCode: report.allPassed ? 0 : 1,
            diagnostics: outcome.diagnostics,
            stdout: report.stdout,
            stderr: report.stderr,
            duration: started.duration(to: clock.now),
            detail: report.allPassed
                ? "\(report.results.passedCount) of \(report.results.count) tests passed."
                : "\(report.results.failedCount) of \(report.results.count) tests failed.",
            tests: report.results
        )
    }

    private func runResult(
        plan: GoBuildPlan,
        job: GoWorkspaceStager.Layout,
        outcome: GoToolSession.Outcome,
        cache: GoArtifactCache,
        key: String,
        started: ContinuousClock.Instant
    ) -> CompilationResult {
        guard let product = plan.products.first,
              let url = job.hostURL(forGuestPath: product.guestPath),
              let data = try? Data(contentsOf: url),
              let program = try? parseWasm(bytes: [UInt8](data))
        else {
            return .failure(
                phase: .build,
                detail: "The toolchain reported success but emitted no program.",
                stderr: outcome.output.stderr,
                duration: started.duration(to: clock.now)
            )
        }

        cache.store(programData: data, module: program, for: key)
        return (try? GoProgramRunner(job: job).run(
            module: program,
            diagnostics: outcome.diagnostics,
            started: started,
            clock: clock,
            successDetail: "Compiled and executed locally inside the bounded WasmKit sandbox."
        )) ?? .failure(
            phase: .run,
            detail: "The program could not be started.",
            duration: started.duration(to: clock.now)
        )
    }
}
