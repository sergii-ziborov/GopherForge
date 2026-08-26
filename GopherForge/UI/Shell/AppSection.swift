import SwiftUI

/// The four places the app can be.
///
/// Kept as one enum so the iPhone tab bar and the iPad sidebar cannot drift
/// apart: both render from this list.
enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case projects
    case build
    case learn
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: "Projects"
        case .build: "Build"
        case .learn: "Learn"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: "folder"
        case .build: "hammer"
        case .learn: "graduationcap"
        case .settings: "gearshape"
        }
    }
}
