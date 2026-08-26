import Foundation

/// One `go test` case outcome.
///
/// Test results are kept apart from diagnostics: a failing test is evidence
/// about the learner's program, while a diagnostic is evidence about the code
/// not compiling at all, and the two drive different UI and different review.
struct GoTestResult: Identifiable, Equatable, Sendable {
    enum Outcome: String, Sendable {
        case passed
        case failed
        case skipped
    }

    let id = UUID()
    let name: String
    let packagePath: String
    let outcome: Outcome
    let elapsedSeconds: Double?
    let output: String
}

extension Collection where Element == GoTestResult {
    var passedCount: Int { count { $0.outcome == .passed } }
    var failedCount: Int { count { $0.outcome == .failed } }
    var allPassed: Bool { !isEmpty && failedCount == 0 }
}
