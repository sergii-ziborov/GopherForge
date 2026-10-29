import Foundation

/// What kind of file the editor is showing, which decides the highlighter, the
/// completion table and the icon.
enum SourceFileKind: String, Sendable, CaseIterable {
    case go
    case goMod
    case goSum
    case markdown
    case html
    case javascript
    case css
    case json
    case shell
    case yaml
    case dockerfile
    case plain

    static func of(path: String) -> SourceFileKind {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if name == "Dockerfile" || name == "Containerfile" || name.hasPrefix("Dockerfile.") { return .dockerfile }
        if name.hasSuffix(".sh") || name.hasSuffix(".bash") { return .shell }
        if name.hasSuffix(".yml") || name.hasSuffix(".yaml") { return .yaml }
        if name == "go.mod" { return .goMod }
        if name == "go.sum" { return .goSum }
        if name.hasSuffix(".go") { return .go }
        if name.hasSuffix(".md") { return .markdown }
        if name.hasSuffix(".html") || name.hasSuffix(".htm") { return .html }
        if [".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx"].contains(where: name.hasSuffix) { return .javascript }
        if name.hasSuffix(".css") { return .css }
        if name.hasSuffix(".json") { return .json }
        return .plain
    }

    var systemImage: String {
        switch self {
        case .go: "chevron.left.forwardslash.chevron.right"
        case .goMod: "shippingbox"
        case .goSum: "lock.doc"
        case .markdown: "doc.text"
        case .html: "globe"
        case .javascript: "curlybraces"
        case .css: "paintbrush"
        case .json: "ellipsis.curlybraces"
        case .shell: "terminal"
        case .yaml: "list.bullet.indent"
        case .dockerfile: "shippingbox"
        case .plain: "doc"
        }
    }

    var isTestFile: Bool { false }

    func tokens(in source: String) -> [GoToken] {
        switch self {
        case .go: GoSyntaxHighlighter().tokens(in: source)
        case .goMod: GoModSyntaxHighlighter().tokens(in: source)
        case .html: HTMLSyntaxHighlighter().tokens(in: source)
        case .javascript: JavaScriptSyntaxHighlighter().tokens(in: source)
        case .css: CSSSyntaxHighlighter().tokens(in: source)
        case .json: JSONSyntaxHighlighter().tokens(in: source)
        case .shell: OperationsSyntaxHighlighter(language: .shell).tokens(in: source)
        case .yaml: OperationsSyntaxHighlighter(language: .yaml).tokens(in: source)
        case .dockerfile: OperationsSyntaxHighlighter(language: .dockerfile).tokens(in: source)
        case .goSum, .markdown, .plain: []
        }
    }
}
