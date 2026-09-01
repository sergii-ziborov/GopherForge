import Foundation

/// The outcome of the last phase run against a project, kept small enough to
/// live in the recent-projects list.
struct ProjectBuildRecord: Codable, Equatable, Sendable {
    let succeeded: Bool
    let phase: CompilationResult.Phase
    let durationMilliseconds: Int
    let finishedAt: Date
    /// Only meaningful for the test phase; nil elsewhere so the UI does not
    /// show "0 tests" for a build.
    let testsPassed: Int?
    let testsFailed: Int?

    init(result: CompilationResult, finishedAt: Date = Date()) {
        succeeded = result.succeeded
        phase = result.phase
        let parts = result.duration.components
        let milliseconds = Double(parts.seconds) * 1_000
            + Double(parts.attoseconds) / 1_000_000_000_000_000
        durationMilliseconds = max(0, Int(milliseconds))
        self.finishedAt = finishedAt
        if result.phase == .test, !result.tests.isEmpty {
            testsPassed = result.tests.passedCount
            testsFailed = result.tests.failedCount
        } else {
            testsPassed = nil
            testsFailed = nil
        }
    }
}
