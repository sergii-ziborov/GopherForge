import SwiftUI

/// Light, dark, or whatever the system is doing.
///
/// Stored as a raw string in `AppStorage` rather than as an index, so adding a
/// mode later cannot silently reinterpret someone's saved choice as a different
/// one.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// `nil` means "do not override", which is what lets Auto follow the
    /// system rather than guessing at launch and being wrong until something
    /// redraws.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Tolerant of an unknown or missing stored value, because a preference
    /// should never be the reason an app fails to start.
    static func stored(_ raw: String?) -> AppearanceMode {
        guard let raw, let mode = AppearanceMode(rawValue: raw) else { return .system }
        return mode
    }
}
