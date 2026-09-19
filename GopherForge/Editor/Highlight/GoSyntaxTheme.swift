import SwiftUI

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
        keyword: Color(red: 0.68, green: 0.24, blue: 0.60),
        type: Color(red: 0.16, green: 0.47, blue: 0.72),
        string: Color(red: 0.76, green: 0.29, blue: 0.20),
        number: Color(red: 0.20, green: 0.44, blue: 0.36),
        comment: Color.secondary,
        function: Color(red: 0.36, green: 0.34, blue: 0.72),
        package: Color(red: 0.24, green: 0.52, blue: 0.44),
        directive: Color(red: 0.55, green: 0.42, blue: 0.16)
    )
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
