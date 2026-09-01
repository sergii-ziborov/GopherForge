import Foundation

/// Launch-time overrides used by UI tests and screenshot automation.
///
/// Reading them here rather than scattering `ProcessInfo` checks through views
/// keeps the surface small and auditable: this is the only place the app lets
/// the outside world decide what it shows at launch.
enum LaunchOptions {
    /// A screen inside a section that automation can open directly.
    enum Screen: String {
        case lab
        case review
        case drills
        case achievements
        case examples
        case packages
    }

    private static let sectionArgument = "-GopherForgeSection"
    private static let screenArgument = "-GopherForgeScreen"
    private static let emptyLibraryArgument = "-GopherForgeEmptyLibrary"

    /// `-GopherForgeSection learn` opens straight to that section.
    static var initialSection: AppSection {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: sectionArgument),
              arguments.indices.contains(index + 1),
              let section = AppSection(rawValue: arguments[index + 1])
        else {
            return .projects
        }
        return section
    }

    /// `-GopherForgeScreen lab` pushes that screen once the section appears.
    static var initialScreen: Screen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: screenArgument),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return Screen(rawValue: arguments[index + 1])
    }

    /// `-GopherForgeEmptyLibrary` starts with no projects at all.
    ///
    /// The landing screen introduces the product only when there is nothing to
    /// show instead, so a test for it that relies on the simulator happening to
    /// be fresh is a test of the simulator rather than of the app. Its writes
    /// go to a throwaway file, so a run cannot leave anything behind either.
    static var usesEmptyLibrary: Bool {
        ProcessInfo.processInfo.arguments.contains(emptyLibraryArgument)
    }
}
