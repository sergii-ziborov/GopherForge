import XCTest
@testable import GopherForge

final class WasmGoCompilerFailureTests: XCTestCase {
    func testAMissingToolchainFailsEveryPhaseAtSetup() async {
        let compiler = WasmGoCompiler(bundle: Bundle(for: Self.self))
        let project = GoSourceSnapshot.singleFile("package main\nfunc main() {}\n")
        for phase in [CompilationResult.Phase.build, .run, .test, .vet, .format] {
            let result: CompilationResult
            switch phase {
            case .build: result = await compiler.build(project: project)
            case .run: result = await compiler.run(project: project)
            case .test: result = await compiler.test(project: project)
            case .vet: result = await compiler.vet(project: project)
            case .format: result = await compiler.format(project: project)
            case .setup: continue
            }
            XCTAssertFalse(result.succeeded, "\(phase) should fail without a toolchain")
            XCTAssertEqual(result.phase, .setup, "\(phase)")
            XCTAssertTrue(
                result.detail.contains("missing") || result.detail.contains("Could not"),
                result.detail
            )
        }
    }

    func testClearingAnEmptyCacheIsSafe() {
        let compiler = WasmGoCompiler(bundle: Bundle(for: Self.self))
        compiler.clearBuildCache()
        XCTAssertEqual(compiler.buildCacheByteCount, 0)
    }

    func testProbeWithoutABundleReportsMissing() {
        let compiler = WasmGoCompiler(bundle: Bundle(for: Self.self))
        XCTAssertFalse(compiler.probe().isReady)
        XCTAssertEqual(compiler.probe(), .missing)
    }
}
