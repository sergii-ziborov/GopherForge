import Foundation

/// Where a build has got to, reported as each step starts.
///
/// A build on a phone takes seconds, not milliseconds, and a spinner that says
/// nothing for that long is indistinguishable from a button that does not
/// work — which is exactly how the first device build was reported. The plan
/// already knows what each step is for; this is that knowledge reaching the
/// screen.
struct GoBuildProgress: Sendable, Equatable {
    /// What this step does, in the planner's words: `compile example.com/forge`.
    let label: String
    /// 1-based, so it reads as "3 of 7" without arithmetic at the call site.
    let step: Int
    let totalSteps: Int

    var fraction: Double {
        totalSteps > 0 ? Double(step) / Double(totalSteps) : 0
    }

    /// `compile fmt · 3 of 7`
    var summary: String {
        totalSteps > 1 ? "\(label) · \(step) of \(totalSteps)" : label
    }
}

/// Receives progress from the compiler's background queue.
///
/// Deliberately a plain `@Sendable` closure rather than a delegate: the
/// compiler must not know that a main actor exists, and the UI must not be
/// touched from the queue a build runs on.
typealias GoBuildProgressHandler = @Sendable (GoBuildProgress) -> Void
