import XCTest
@testable import GopherForge

final class GoBuildPlanTests: XCTestCase {
    func testCompileAndLinkWriteDiagnosticsOnStdout() {
        XCTAssertTrue(GoToolStep.Tool.compile.writesDiagnosticsToStandardOutput)
        XCTAssertTrue(GoToolStep.Tool.link.writesDiagnosticsToStandardOutput)
        XCTAssertFalse(GoToolStep.Tool.vet.writesDiagnosticsToStandardOutput)
        XCTAssertFalse(GoToolStep.Tool.format.writesDiagnosticsToStandardOutput)
    }

    func testAnEmptyPlanHasNoStepsOrProducts() {
        let plan = GoBuildPlan(steps: [], products: [])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(plan.products.isEmpty)
    }

    func testAStepCarriesGeneratedFilesAndALabel() {
        let step = GoToolStep(
            tool: .format,
            arguments: ["gofmt", "-l", "/work/main.go"],
            generatedFiles: ["/tmp/x": "packagefile fmt=/goroot/pkg/fmt.a\n"],
            label: "gofmt",
            outputPath: nil,
            cacheKey: nil
        )
        XCTAssertEqual(step.tool, .format)
        XCTAssertEqual(step.generatedFiles.count, 1)
        XCTAssertNil(step.outputPath)
        XCTAssertNil(step.cacheKey)
    }
}
