import SwiftUI

/// The product's visual vocabulary.
///
/// GopherForge is a forge: warm metal against cool slate. It is deliberately
/// nothing like the Rust sibling's palette, because the two are separate
/// products and should not read as one app with a different accent colour.
enum GopherForgeTheme {
    static let ember = Color(red: 0.85, green: 0.45, blue: 0.16)
    static let emberDim = Color(red: 0.62, green: 0.33, blue: 0.12)
    static let slate = Color(red: 0.16, green: 0.20, blue: 0.25)
    static let anvil = Color(red: 0.32, green: 0.38, blue: 0.44)

    static let accent = ember

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
}
