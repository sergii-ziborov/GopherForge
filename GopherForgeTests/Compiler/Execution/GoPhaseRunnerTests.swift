import XCTest
@testable import GopherForge

private final class LockingList: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

/// The phase runner, without a real toolchain: refusals and empty plans.
final class GoPhaseRunnerTests: XCTestCase {
    private func runner(
        onProgress: @escaping GoBuildProgressHandler = { _ in }
    ) -> GoPhaseRunner {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "phase-layout-\(UUID().uuidString)", directoryHint: .isDirectory)
        let layout = GoToolchainLocator.Layout(
            root: root,
            compiler: root.appending(path: "compile.wasm"),
            linker: root.appending(path: "link.wasm"),
            vet: nil,
            formatter: nil,
            goroot: root.appending(path: "goroot"),
            tag: "phase-runner"
        )
        return GoPhaseRunner(
            layout: layout,
            stager: GoWorkspaceStager(),
            clock: ContinuousClock(),
            goVersion: "go1.24",
            module: { _ in throw GoToolSession.SessionError.toolNotBundled("compile") },
            artifacts: nil,
            onProgress: onProgress
        )
    }

    private func cache() -> GoArtifactCache {
        GoArtifactCache(toolchainTag: "phase-\(UUID().uuidString)")
    }

    func testATraversingPathFailsBeforeAnyToolRuns() {
        let cache = cache()
        defer { cache.clear() }
        let result = runner().run(
            GoBuildPlan(steps: [], products: []),
            phase: .build,
            project: GoSourceSnapshot(files: ["../escape.go": "package main\n"]),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.phase, .setup)
        XCTAssertTrue(result.detail.contains("Invalid project path"))
        XCTAssertTrue(result.detail.contains("../escape.go"))
    }

    func testADotDotComponentIsRejected() {
        let cache = cache()
        defer { cache.clear() }
        let result = runner().run(
            GoBuildPlan(steps: [], products: []),
            phase: .setup,
            project: GoSourceSnapshot(files: ["foo/../bar.go": "package main\n"]),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.detail.contains("Invalid project path"))
    }

    func testAMissingToolIsARuntimeFailureNotASilentPass() {
        let cache = cache()
        defer { cache.clear() }
        let plan = GoBuildPlan(
            steps: [
                GoToolStep(
                    tool: .compile,
                    arguments: ["compile"],
                    generatedFiles: [:],
                    label: "compile playground"
                ),
            ],
            products: []
        )
        let result = runner().run(
            plan,
            phase: .build,
            project: .singleFile("package main\nfunc main() {}\n"),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.detail.contains("Native toolchain runtime failed"))
    }

    func testAnEmptyTestPlanReportsNothingToRun() {
        let cache = cache()
        defer { cache.clear() }
        let result = runner().run(
            GoBuildPlan(steps: [], products: []),
            phase: .test,
            project: .singleFile("package main\n"),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.phase, .test)
        XCTAssertTrue(result.detail.contains("No test files"))
    }

    func testARunThatProducedNoProgramFails() {
        let cache = cache()
        defer { cache.clear() }
        let result = runner().run(
            GoBuildPlan(
                steps: [],
                products: [.init(guestPath: "/work/program.wasm", importPath: "main")]
            ),
            phase: .run,
            project: .singleFile("package main\nfunc main() {}\n"),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.phase, .build)
        XCTAssertTrue(result.detail.contains("no program"))
    }

    func testAnEmptyBuildPlanIsAcceptedAndRemembered() {
        let cache = cache()
        defer { cache.clear() }
        let key = "accepted"
        let result = runner().run(
            GoBuildPlan(steps: [], products: []),
            phase: .build,
            project: .singleFile("package main\n"),
            cache: cache,
            key: key,
            started: ContinuousClock().now
        )
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(cache.hasAcceptedBuild(for: key))
    }

    func testProgressIsReportedWhenTestsWouldRun() {
        let labels = LockingList()
        let cache = cache()
        defer { cache.clear() }
        _ = runner(onProgress: { labels.append($0.label) }).run(
            GoBuildPlan(
                steps: [],
                products: [.init(guestPath: "/work/missing.wasm", importPath: "main")]
            ),
            phase: .test,
            project: .singleFile("package main\n"),
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        XCTAssertTrue(labels.snapshot().contains { $0.contains("test") })
    }

    func testAPersistentProjectReusesTheWorkTree() throws {
        let cache = cache()
        defer { cache.clear() }
        let reuse = UUID().uuidString
        let project = GoSourceSnapshot(
            files: ["main.go": "package main\n"],
            workspaceReuseKey: reuse
        )
        _ = runner().run(
            GoBuildPlan(steps: [], products: []),
            phase: .build,
            project: project,
            cache: cache,
            key: "k",
            started: ContinuousClock().now
        )
        let work = GoWorkspaceStager.persistentRootURL(for: reuse)
            .appending(path: "work")
            .appending(path: "main.go")
        XCTAssertTrue(FileManager.default.fileExists(atPath: work.path))
        try? FileManager.default.removeItem(at: GoWorkspaceStager.persistentRootURL(for: reuse))
    }
}
