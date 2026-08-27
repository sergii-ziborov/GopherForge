import Foundation
import WasmKit

/// The app's entry point to the bundled Go toolchain.
///
/// Every phase follows the same shape — plan the work, check the cache, run the
/// plan — so this type stays an orchestrator. Planning is
/// `GoBuildPlanner`'s, running is `GoPhaseRunner`'s, and what lives here is the
/// state all jobs share: the parsed tool modules, the standard-library index
/// and the artifact caches.
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
    private var modules: [String: Module] = [:]
    private var indexes: [String: GoStandardLibraryIndex] = [:]
    private var caches: [String: GoArtifactCache] = [:]

    init(bundle: Bundle = .main) {
        locator = GoToolchainLocator(bundle: bundle)
    }

    func probe() -> ToolchainStatus {
        locator.probe()
    }

    /// Forgets every built artifact. Used by Settings to reclaim storage, and
    /// by the compiler gate so that a build it asserts on is one that actually
    /// happened rather than one that was remembered.
    func clearBuildCache() {
        let existing = lock.withLock { Array(caches.values) }
        for cache in existing { cache.clear() }
        // A tag with no cache yet still has a directory from a previous run.
        if let layout = locator.resolve() {
            GoArtifactCache(toolchainTag: layout.tag).clear()
        }
    }

    /// Bytes the build cache currently occupies.
    var buildCacheByteCount: Int64 {
        guard let layout = locator.resolve() else { return 0 }
        return artifactCache(for: layout.tag).storedByteCount
    }

    func format(
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) async -> CompilationResult {
        await perform(phase: .format, project: project, onProgress: onProgress)
    }

    func vet(
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) async -> CompilationResult {
        await perform(phase: .vet, project: project, onProgress: onProgress)
    }

    func build(
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) async -> CompilationResult {
        await perform(phase: .build, project: project, onProgress: onProgress)
    }

    func run(
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) async -> CompilationResult {
        await perform(phase: .run, project: project, onProgress: onProgress)
    }

    func test(
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) async -> CompilationResult {
        await perform(phase: .test, project: project, onProgress: onProgress)
    }

    private func perform(
        phase: CompilationResult.Phase,
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler
    ) async -> CompilationResult {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                assert(!Thread.isMainThread, "The bundled toolchain must never execute on the UI thread")
                continuation.resume(
                    returning: execute(phase: phase, project: project, onProgress: onProgress)
                )
            }
        }
    }

    private func execute(
        phase: CompilationResult.Phase,
        project: GoSourceSnapshot,
        onProgress: @escaping GoBuildProgressHandler
    ) -> CompilationResult {
        let started = clock.now
        guard let layout = locator.resolve() else {
            return .failure(phase: .setup, detail: "Bundled Go toolchain is missing.")
        }

        let plan: GoBuildPlan
        do {
            plan = try planner(for: layout, project: project).plan(phase: phase, files: project.files)
        } catch let error as GoPackageGraph.GraphError {
            return .failure(
                phase: .setup,
                detail: GoPlanFailureReader.describe(error),
                duration: started.duration(to: clock.now)
            )
        } catch {
            return .failure(
                phase: .setup,
                detail: "Could not work out how to build this project: \(error)",
                duration: started.duration(to: clock.now)
            )
        }

        let cache = artifactCache(for: layout.tag)
        let key = cache.key(phase: phase, files: project.files)
        if let cached = cachedResult(phase: phase, key: key, cache: cache, started: started) {
            return cached
        }

        return runner(for: layout, onProgress: onProgress).run(
            plan,
            phase: phase,
            project: project,
            cache: cache,
            key: key,
            started: started
        )
    }

    // MARK: - Cache

    private func cachedResult(
        phase: CompilationResult.Phase,
        key: String,
        cache: GoArtifactCache,
        started: ContinuousClock.Instant
    ) -> CompilationResult? {
        switch phase {
        case .build, .vet:
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
                  let job = try? stager.createLayout(named: UUID().uuidString)
            else {
                return nil
            }
            defer { stager.remove(job) }
            return try? GoProgramRunner(job: job).run(
                module: module,
                diagnostics: [],
                started: started,
                clock: clock,
                successDetail: "Executed a cached local build artifact inside the bounded WasmKit sandbox."
            )
        // Formatting rewrites files, so a cache hit would hide the rewrite;
        // tests are re-run because their output is the point.
        case .format, .test, .setup:
            return nil
        }
    }

    // MARK: - Shared state

    private func runner(
        for layout: GoToolchainLocator.Layout,
        onProgress: @escaping GoBuildProgressHandler
    ) -> GoPhaseRunner {
        GoPhaseRunner(
            layout: layout,
            stager: stager,
            clock: clock,
            goVersion: locator.probe().goVersion,
            module: { [self] tool in try module(for: tool, in: layout) },
            onProgress: onProgress
        )
    }

    private func planner(
        for layout: GoToolchainLocator.Layout,
        project: GoSourceSnapshot
    ) -> GoBuildPlanner {
        GoBuildPlanner(
            modulePath: modulePath(of: project),
            languageVersion: GoToolchainLocator.languageVersion(
                fromGoVersion: locator.probe().goVersion
            ),
            standardLibrary: standardLibrary(for: layout).importPaths
        )
    }

    private func modulePath(of project: GoSourceSnapshot) -> String {
        guard let source = project.files["go.mod"],
              let module = GoModParser.parse(source),
              !module.modulePath.isEmpty
        else {
            return "playground"
        }
        return module.modulePath
    }

    private func standardLibrary(for layout: GoToolchainLocator.Layout) -> GoStandardLibraryIndex {
        lock.withLock {
            if let index = indexes[layout.tag] { return index }
            let index = GoStandardLibraryIndex.load(packageRoot: layout.standardLibraryPackages)
            indexes[layout.tag] = index
            return index
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

    /// Parsing a 38 MB module is the single most expensive thing the app does,
    /// so each tool is parsed once and reused for every job after that.
    private func module(for tool: GoToolStep.Tool, in layout: GoToolchainLocator.Layout) throws -> Module {
        if let cached = lock.withLock({ modules[tool.rawValue] }) { return cached }
        guard let url = layout.module(for: tool) else {
            throw GoToolSession.SessionError.toolNotBundled(tool.rawValue)
        }
        let module = try parseWasm(bytes: [UInt8](Data(contentsOf: url)))
        lock.withLock { modules[tool.rawValue] = module }
        return module
    }
}
