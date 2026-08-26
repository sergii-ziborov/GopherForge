import Foundation
import WasmKit

/// The app's entry point to the bundled Go toolchain.
///
/// Every phase follows the same shape — stage the project, run the driver,
/// parse what it wrote — so this type stays an orchestrator and delegates the
/// staging, invocation, execution and caching to their own components.
///
/// The toolchain runs synchronously inside the Wasm interpreter, below the
/// UI's quality of service, so scrolling and animation stay responsive while a
/// build is in flight.
final class WasmGoCompiler: @unchecked Sendable {
    private let locator: GoToolchainLocator
    private let queue = DispatchQueue(
        label: "com.sergiiziborov.GopherForge.compiler",
        qos: .utility,
        autoreleaseFrequency: .workItem
    )
    private let clock = ContinuousClock()
    private let stager = GoWorkspaceStager()
    private let lock = NSLock()
    private var cachedDriver: Module?
    private var caches: [String: GoArtifactCache] = [:]

    init(bundle: Bundle = .main) {
        locator = GoToolchainLocator(bundle: bundle)
    }

    func probe() -> ToolchainStatus {
        locator.probe()
    }

    func format(project: GoSourceSnapshot) async -> CompilationResult {
        await perform(phase: .format, project: project)
    }

    func vet(project: GoSourceSnapshot) async -> CompilationResult {
        await perform(phase: .vet, project: project)
    }

    func build(project: GoSourceSnapshot) async -> CompilationResult {
        await perform(phase: .build, project: project)
    }

    func run(project: GoSourceSnapshot) async -> CompilationResult {
        await perform(phase: .run, project: project)
    }

    func test(project: GoSourceSnapshot) async -> CompilationResult {
        await perform(phase: .test, project: project)
    }

    private func perform(phase: CompilationResult.Phase, project: GoSourceSnapshot) async -> CompilationResult {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                assert(!Thread.isMainThread, "The bundled toolchain must never execute on the UI thread")
                continuation.resume(returning: execute(phase: phase, project: project))
            }
        }
    }

    private func execute(phase: CompilationResult.Phase, project: GoSourceSnapshot) -> CompilationResult {
        let started = clock.now
        guard let layout = locator.resolve() else {
            return .failure(phase: .setup, detail: "Bundled Go toolchain is missing.")
        }
        let cache = artifactCache(for: layout.tag)
        let key = cache.key(phase: phase, files: project.files)

        if let cached = cachedResult(phase: phase, key: key, cache: cache, started: started, layout: layout) {
            return cached
        }

        let jobLayout: GoWorkspaceStager.Layout
        do {
            jobLayout = try stager.createLayout(named: UUID().uuidString)
            try stager.stage(files: project.files, into: jobLayout.work)
        } catch let error as GoWorkspaceStager.StagingError {
            guard case let .invalidPath(path) = error else {
                return .failure(phase: .setup, detail: "Invalid project layout.")
            }
            return .failure(
                phase: .setup,
                detail: "Invalid project path: \(path)",
                duration: started.duration(to: clock.now)
            )
        } catch {
            return .failure(
                phase: .setup,
                detail: "Could not create the compiler sandbox: \(error.localizedDescription)",
                duration: started.duration(to: clock.now)
            )
        }
        defer { stager.remove(jobLayout) }

        do {
            let session = GoToolSession(
                driver: try driverModule(at: layout.driver),
                goVersion: locator.probe().goVersion,
                layout: layout,
                job: jobLayout,
                sources: project
            )
            let outcome = try session.run(phase: phase, packagePattern: project.packagePattern)
            let elapsed = started.duration(to: clock.now)

            guard phase == .run, outcome.succeeded else {
                if outcome.succeeded { cache.rememberAcceptedBuild(for: key) }
                return outcome.result(phase: phase, duration: elapsed)
            }

            let programURL = jobLayout.work.appendingPathComponent("program.wasm")
            guard let programData = try? Data(contentsOf: programURL) else {
                return .failure(
                    phase: .build,
                    detail: "The toolchain reported success but emitted no program.wasm.",
                    stderr: outcome.output.stderr,
                    duration: elapsed
                )
            }
            let programModule = try parseWasm(bytes: [UInt8](programData))
            cache.store(programData: programData, module: programModule, for: key)

            return try GoProgramRunner(job: jobLayout).run(
                module: programModule,
                diagnostics: outcome.diagnostics,
                started: started,
                clock: clock,
                successDetail: "Compiled and executed locally inside the bounded WasmKit sandbox."
            )
        } catch {
            return .failure(
                phase: phase,
                detail: "Native toolchain runtime failed: \(error)",
                duration: started.duration(to: clock.now)
            )
        }
    }

    private func cachedResult(
        phase: CompilationResult.Phase,
        key: String,
        cache: GoArtifactCache,
        started: ContinuousClock.Instant,
        layout: GoToolchainLocator.Layout
    ) -> CompilationResult? {
        switch phase {
        case .build, .vet, .format:
            guard cache.hasAcceptedBuild(for: key) else { return nil }
            return CompilationResult(
                succeeded: true,
                phase: phase,
                exitCode: 0,
                diagnostics: [],
                stdout: "",
                stderr: "",
                duration: started.duration(to: clock.now),
                detail: "Unchanged snapshot accepted from the local build cache."
            )
        case .run:
            guard let module = cache.module(for: key),
                  let jobLayout = try? stager.createLayout(named: UUID().uuidString)
            else {
                return nil
            }
            defer { stager.remove(jobLayout) }
            return try? GoProgramRunner(job: jobLayout).run(
                module: module,
                diagnostics: [],
                started: started,
                clock: clock,
                successDetail: "Executed a cached local build artifact inside the bounded WasmKit sandbox."
            )
        case .test, .setup:
            return nil
        }
    }

    private func artifactCache(for tag: String) -> GoArtifactCache {
        lock.withLock {
            if let cache = caches[tag] { return cache }
            let cache = GoArtifactCache(toolchainTag: tag)
            caches[tag] = cache
            return cache
        }
    }

    private func driverModule(at url: URL) throws -> Module {
        if let cachedDriver = lock.withLock({ cachedDriver }) { return cachedDriver }
        let module = try parseWasm(bytes: [UInt8](Data(contentsOf: url)))
        lock.withLock { cachedDriver = module }
        return module
    }
}
