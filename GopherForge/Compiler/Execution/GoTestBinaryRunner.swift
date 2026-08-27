import Foundation
import WasmKit

/// Runs the test binaries a plan linked and reports what they printed.
///
/// `go test` normally wraps each binary and prints the `ok <package>` line that
/// closes a package's output. There is no `go test` here, so the wrapper line
/// is written from what the run actually did — the package that was linked and
/// the code it exited with — rather than being inferred from the text.
struct GoTestBinaryRunner {
    private let job: GoWorkspaceStager.Layout

    init(job: GoWorkspaceStager.Layout) {
        self.job = job
    }

    struct Report {
        let stdout: String
        let stderr: String
        let allPassed: Bool
        let results: [GoTestResult]
    }

    func run(products: [GoBuildPlan.Product]) -> Report {
        var stdout = ""
        var stderr = ""
        var allPassed = true

        for product in products {
            let outcome = runOne(product)
            stdout += outcome.stdout
            stderr += outcome.stderr
            allPassed = allPassed && outcome.passed
        }

        return Report(
            stdout: stdout,
            stderr: stderr,
            allPassed: allPassed,
            results: GoTestOutputParser.parse(stdout: stdout)
        )
    }

    private func runOne(_ product: GoBuildPlan.Product) -> (stdout: String, stderr: String, passed: Bool) {
        guard let url = job.hostURL(forGuestPath: product.guestPath),
              let data = try? Data(contentsOf: url),
              let module = try? parseWasm(bytes: [UInt8](data))
        else {
            return ("FAIL\t\(product.importPath) [build failed]\n", "", false)
        }

        let runner = WasiProcessRunner(captureDirectory: job.jobRoot, capturePrefix: "test")
        let invocation = WasiProcessRunner.Invocation(
            arguments: [product.importPath + ".test", "-test.v"],
            preopens: [WasmSandboxPolicy.writableGuestDirectory: job.sandbox.path],
            memoryLimitBytes: WasmSandboxPolicy.userProgramMemoryLimitBytes,
            tableElementLimit: WasmSandboxPolicy.userProgramTableElementLimit
        )

        do {
            let (exitCode, output) = try runner.run(module: module, invocation: invocation)
            let passed = exitCode == 0
            let banner = passed ? "ok  \t\(product.importPath)\n" : "FAIL\t\(product.importPath)\n"
            // The banner leads: the parser attributes every case that follows
            // to the package named on the line above it.
            return (banner + output.stdout, output.stderr, passed)
        } catch {
            return (
                "FAIL\t\(product.importPath)\n",
                GoRuntimeFailureReader.describe(stderr: "") ?? "The test binary stopped: \(error)",
                false
            )
        }
    }
}
