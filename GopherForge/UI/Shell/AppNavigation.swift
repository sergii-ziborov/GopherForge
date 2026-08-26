import Foundation
import Observation

/// Where the app is, shared by the shell and by anything that needs to move it.
///
/// Opening a project has to land the user in the editor: without this, tapping
/// a template changes state the user cannot see and looks like nothing
/// happened.
@MainActor
@Observable
final class AppNavigation {
    var section: AppSection

    init(section: AppSection = LaunchOptions.initialSection) {
        self.section = section
    }

    func show(_ section: AppSection) {
        self.section = section
    }
}
