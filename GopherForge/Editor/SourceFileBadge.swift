import SwiftUI

/// The icon and colour a file gets in the tree.
///
/// `SourceFileKind` answers "what does the highlighter do with this", which is
/// not the same question. Three files that are all `.go` can be the program's
/// entry point, its tests and an ordinary package file, and in a list of a
/// dozen names those are the distinctions worth seeing without reading.
enum SourceFileBadge: String, Sendable, CaseIterable {
    case entryPoint
    case test
    case source
    case module
    case checksums
    case documentation
    case other

    static func of(path: String) -> SourceFileBadge {
        let name = path.split(separator: "/").last.map(String.init) ?? path

        if name == "go.mod" { return .module }
        if name == "go.sum" { return .checksums }
        if name.hasSuffix("_test.go") { return .test }
        // Only the module root's main.go is the program's front door; a main.go
        // inside cmd/tool is one too, but a file called main.go in a library
        // directory is not, and Go decides that by package clause rather than
        // by name. The name is the honest approximation for a list icon.
        if name == "main.go" { return .entryPoint }
        if name.hasSuffix(".go") { return .source }
        if name.hasSuffix(".md") || name.hasSuffix(".txt") { return .documentation }
        return .other
    }

    var systemImage: String {
        switch self {
        case .entryPoint: "play.square.fill"
        case .test: "testtube.2"
        case .source: "chevron.left.forwardslash.chevron.right"
        case .module: "shippingbox.fill"
        case .checksums: "lock.doc.fill"
        case .documentation: "doc.text"
        case .other: "doc"
        }
    }

    var tint: Color {
        switch self {
        case .entryPoint: GopherForgeTheme.anvil
        case .test: .green
        case .source: .blue
        case .module: .purple
        case .checksums: .secondary
        case .documentation: .teal
        case .other: .secondary
        }
    }

    /// Spoken instead of the symbol name, which VoiceOver would otherwise read
    /// as "chevron left forward slash chevron right".
    var accessibilityDescription: String {
        switch self {
        case .entryPoint: "program entry point"
        case .test: "test file"
        case .source: "Go source"
        case .module: "module definition"
        case .checksums: "module checksums"
        case .documentation: "documentation"
        case .other: "file"
        }
    }
}
