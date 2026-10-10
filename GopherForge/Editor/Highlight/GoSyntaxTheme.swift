import SwiftUI
import UIKit

/// Colours for the editor, defined once and resolved against the current
/// appearance so light and dark are a single source of truth.
struct GoSyntaxTheme: Sendable {
    let plain: Color
    let keyword: Color
    let type: Color
    let string: Color
    let number: Color
    let comment: Color
    let function: Color
    let package: Color
    let directive: Color

    static let standard = GoSyntaxTheme(
        plain: .primary,
        keyword: adaptive(light: 0x9D2A91, dark: 0xDF9CE7),
        type: adaptive(light: 0x236C9C, dark: 0x8ACDFA),
        string: adaptive(light: 0xAD392B, dark: 0xFFA88C),
        number: adaptive(light: 0x206F4F, dark: 0x8FDEAE),
        comment: Color.secondary,
        function: adaptive(light: 0x5551AE, dark: 0xB8B5FF),
        package: adaptive(light: 0x286F60, dark: 0x80D6C1),
        directive: adaptive(light: 0x806011, dark: 0xE9CB79)
    )

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) })
    }
}

/// The token kinds the highlighters produce. Kept separate from the theme so a
/// tokenizer never has to know what a colour is.
enum GoTokenKind: Sendable {
    case plain
    case keyword
    case type
    case string
    case number
    case comment
    case function
    case package
    case directive

    func color(in theme: GoSyntaxTheme) -> Color {
        switch self {
        case .plain: theme.plain
        case .keyword: theme.keyword
        case .type: theme.type
        case .string: theme.string
        case .number: theme.number
        case .comment: theme.comment
        case .function: theme.function
        case .package: theme.package
        case .directive: theme.directive
        }
    }
}

struct GoToken: Equatable, Sendable {
    let range: Range<String.Index>
    let kind: GoTokenKind
}
