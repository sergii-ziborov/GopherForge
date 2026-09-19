import Foundation

/// What the workspace chrome offers. Kept out of the view so a test can
/// describe the toolbar without instantiating SwiftUI.
enum WorkspaceToolbarActions {
    /// Run, Beautify and Tests sit on the bar. Compile-check is a project
    /// menu item: it is useful, but it is not the thing a thumb reaches for.
    static let primaryPhases: [CompilationResult.Phase] = [.run, .format, .test]
}
