import Foundation

extension WorkspacePane {
    /// The pane worth showing once a run finishes.
    ///
    /// Pressing Run and being left staring at the source is the app hiding its
    /// own answer. Whatever was asked for, the reason the button was pressed is
    /// the output, the failure, or the test results — so the workspace goes
    /// there by itself.
    ///
    /// `nil` means "stay where you are", which is right for a format that
    /// worked: there the code on screen *is* the result, and switching away
    /// from it would hide the very thing that changed.
    static func afterRun(_ result: CompilationResult) -> WorkspacePane? {
        // A test run that got as far as running tests is answered by the test
        // list whether they passed or not. Only a build that never produced a
        // test is a Problems question.
        if result.phase == .test, !result.tests.isEmpty { return .tests }

        // Diagnostics are what will fix a failure, so they outrank the output
        // stream even when the tool wrote something to it.
        if !result.succeeded, !result.diagnostics.isEmpty { return .problems }

        if result.phase == .format { return result.succeeded ? nil : .problems }

        // Vet finds things in code that compiles: its whole result is the list.
        if result.phase == .vet { return result.diagnostics.isEmpty ? .output : .problems }

        return .output
    }
}
