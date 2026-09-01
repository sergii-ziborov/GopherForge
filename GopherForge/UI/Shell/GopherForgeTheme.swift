import SwiftUI
import UIKit

/// The product's visual vocabulary, taken from Go's own palette.
///
/// The app used to be warm metal on slate — a forge. It read as the Rust
/// sibling with a different accent, because orange is Rust's colour, and a Go
/// app that opens orange is telling the learner the wrong thing before a word
/// is read. These are the colours the Go project publishes for itself.
///
/// Two blues rather than one. Gopher Blue is a fill colour: it carries a
/// white glyph well and fails as text, at roughly 2.4:1 on white. Text and
/// controls use the darker blue instead, which clears 4.5:1, and the light one
/// takes over in the dark where the dark one would sink into the background.
enum GopherForgeTheme {
    // MARK: - Go's published palette

    /// Gopher Blue, the colour the language is known by. A fill, not a text
    /// colour.
    static let gopherBlue = Color(hex: 0x00ADD8)
    /// The darker blue of Go's own site, used wherever the colour has to carry
    /// a word rather than sit behind one.
    static let deepBlue = Color(hex: 0x007D9C)
    static let sky = Color(hex: 0x5DC9E2)
    static let aqua = Color(hex: 0x00A29C)
    static let berry = Color(hex: 0xCE3262)
    static let sun = Color(hex: 0xFDDD00)
    static let mist = Color(hex: 0xDBD9D6)

    // MARK: - Roles

    /// The app's tint. Adaptive, because one blue cannot be legible on both
    /// grounds.
    static let accent = adaptive(light: 0x007D9C, dark: 0x5DC9E2)

    /// The accent where the colour is a background and the contrast is carried
    /// by what sits on it.
    static let accentSolid = gopherBlue

    /// The quiet neutral: secondary marks, inactive states, structure.
    static let slate = adaptive(light: 0x555759, dark: 0xA4AAAF)

    /// A wash of the accent, for cards and rings that should read as ours
    /// without shouting.
    static func accentWash(_ opacity: Double = 0.14) -> Color {
        gopherBlue.opacity(opacity)
    }

    /// Something the learner should look at but that is not an error.
    static let warning = adaptive(light: 0xB07B00, dark: 0xFDDD00)

    static func statusColor(succeeded: Bool?) -> Color {
        switch succeeded {
        case .some(true): .green
        case .some(false): .red
        case nil: .secondary
        }
    }

    /// Phase labels shown on buttons and in the build dock.
    static func label(for phase: CompilationResult.Phase) -> String {
        switch phase {
        case .format: "Format"
        case .vet: "Vet"
        case .build: "Build"
        case .run: "Run"
        case .test: "Test"
        case .setup: "Setup"
        }
    }

    static func systemImage(for phase: CompilationResult.Phase) -> String {
        switch phase {
        case .format: "text.alignleft"
        case .vet: "magnifyingglass"
        case .build: "hammer"
        case .run: "play.fill"
        case .test: "checkmark.diamond"
        case .setup: "wrench.and.screwdriver"
        }
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

extension Color {
    /// From the hex the Go brand page states, so the constants above can be
    /// read against it without converting anything by hand.
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
