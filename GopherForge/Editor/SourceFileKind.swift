import Foundation

/// What kind of file the editor is showing, which decides the highlighter, the
/// completion table and the icon.
enum SourceFileKind: String, Sendable, CaseIterable {
    case go
    case goMod
    case goSum
    case markdown
    case plain

    static func of(path: String) -> SourceFileKind {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if name == "go.mod" { return .goMod }
        if name == "go.sum" { return .goSum }
        if name.hasSuffix(".go") { return .go }
        if name.hasSuffix(".md") { return .markdown }
        return .plain
    }

    var systemImage: String {
        switch self {
        case .go: "chevron.left.forwardslash.chevron.right"
        case .goMod: "shippingbox"
        case .goSum: "lock.doc"
        case .markdown: "doc.text"
        case .plain: "doc"
        }
    }

    var isTestFile: Bool { false }

    func tokens(in source: String) -> [GoToken] {
        switch self {
        case .go: GoSyntaxHighlighter().tokens(in: source)
        case .goMod: GoModSyntaxHighlighter().tokens(in: source)
        case .goSum, .markdown, .plain: []
        }
    }
}
