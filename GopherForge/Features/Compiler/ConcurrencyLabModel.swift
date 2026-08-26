import Foundation
import Observation

/// Runs a lab scenario and turns its output into a trace.
@MainActor
@Observable
final class ConcurrencyLabModel {
    private(set) var scenario: ConcurrencyLabScenario
    private(set) var trace: ConcurrencyTrace?
    private(set) var diagnoses: [ConcurrencyDiagnosis] = []
    private(set) var programOutput = ""
    private(set) var isRunning = false
    private(set) var failureDetail: String?
    var hasPredicted = false

    private let compiler: WasmGoCompiler

    init(
        scenario: ConcurrencyLabScenario = ConcurrencyLabScenario.unbufferedRendezvous,
        compiler: WasmGoCompiler = WasmGoCompiler()
    ) {
        self.scenario = scenario
        self.compiler = compiler
    }

    func select(_ scenario: ConcurrencyLabScenario) {
        self.scenario = scenario
        trace = nil
        diagnoses = []
        programOutput = ""
        failureDetail = nil
        hasPredicted = false
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let result = await compiler.run(project: scenario.snapshot)
        let events = ConcurrencyTraceReader.events(in: result.stdout)
        let builtTrace = ConcurrencyTrace(events: events)

        trace = builtTrace
        programOutput = ConcurrencyTraceReader.programOutput(in: result.stdout)
        diagnoses = ConcurrencyDiagnosis.diagnose(builtTrace, runtimeStderr: result.stderr)
        // A scenario that ends in a runtime deadlock is a successful lesson and
        // a failed program, so the detail is kept rather than shown as an error.
        failureDetail = result.succeeded ? nil : result.detail
    }
}
