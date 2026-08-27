import Foundation

/// The package clause and imports at the top of one Go file.
///
/// The app drives `compile` and `link` directly rather than `cmd/go`, because
/// `cmd/go` builds by spawning those tools and WASI has no way to spawn
/// anything. That trade buys a toolchain with no patches against upstream Go,
/// and costs exactly this: the app has to work out for itself which packages
/// exist and what they import.
///
/// Only the header is read, and only as far as the first top-level declaration.
/// Go requires every import to appear before any other declaration, so nothing
/// past that point can change the answer — which is what makes a scanner this
/// small correct rather than merely convenient.
struct GoSourceHeader: Equatable {
    let packageName: String
    let imports: [String]

    /// True for the `package foo_test` form, which is compiled as its own
    /// package and may import the package under test.
    var isExternalTestPackage: Bool {
        packageName.hasSuffix("_test")
    }

    static func parse(_ source: String) -> GoSourceHeader {
        var packageName = ""
        var imports: [String] = []
        var inBlockComment = false
        var inImportGroup = false

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = strippingComments(String(rawLine), inBlockComment: &inBlockComment)
                .trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if inImportGroup {
                if line.hasPrefix(")") {
                    inImportGroup = false
                } else if let path = importPath(inSpec: line) {
                    imports.append(path)
                }
                continue
            }

            if packageName.isEmpty, let name = packageClause(in: line) {
                packageName = name
                continue
            }

            if line == "import (" || line.hasPrefix("import (") {
                inImportGroup = true
                // `import ("fmt")` on one line is legal, if rare.
                let remainder = String(line.dropFirst("import (".count))
                if let path = importPath(inSpec: remainder) { imports.append(path) }
                if remainder.contains(")") { inImportGroup = false }
                continue
            }

            if line.hasPrefix("import ") {
                if let path = importPath(inSpec: String(line.dropFirst("import ".count))) {
                    imports.append(path)
                }
                continue
            }

            // The first declaration that is not a package clause or an import
            // ends the header, and Go guarantees no import follows it.
            if isTopLevelDeclaration(line) { break }
        }

        return GoSourceHeader(packageName: packageName, imports: imports)
    }

    // MARK: - Line reading

    private static func packageClause(in line: String) -> String? {
        guard line.hasPrefix("package ") else { return nil }
        let name = line.dropFirst("package ".count).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : String(name)
    }

    private static func isTopLevelDeclaration(_ line: String) -> Bool {
        for keyword in ["func ", "type ", "var ", "const ", "//go:"] where line.hasPrefix(keyword) {
            return true
        }
        return false
    }

    /// One import spec, with or without a leading name: `_ "embed"`,
    /// `alias "path"`, `. "path"` or plain `"path"`.
    private static func importPath(inSpec spec: String) -> String? {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard let opening = trimmed.firstIndex(where: { $0 == "\"" || $0 == "`" }) else { return nil }
        let quote = trimmed[opening]
        let afterOpening = trimmed.index(after: opening)
        guard let closing = trimmed[afterOpening...].firstIndex(of: quote) else { return nil }
        let path = String(trimmed[afterOpening..<closing])
        return path.isEmpty ? nil : path
    }

    /// Removes comments so an import inside one is never counted.
    ///
    /// A quoted string is tracked because an import path is a string literal
    /// and could, in principle, contain the characters that open a comment.
    private static func strippingComments(_ line: String, inBlockComment: inout Bool) -> String {
        var result = ""
        var quote: Character?
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            let next = line.index(after: index)

            if inBlockComment {
                if character == "*", next < line.endIndex, line[next] == "/" {
                    inBlockComment = false
                    index = line.index(after: next)
                    continue
                }
                index = next
                continue
            }

            if let open = quote {
                result.append(character)
                if character == open { quote = nil }
                index = next
                continue
            }

            if character == "\"" || character == "`" {
                quote = character
                result.append(character)
                index = next
                continue
            }

            if character == "/", next < line.endIndex {
                if line[next] == "/" { return result }
                if line[next] == "*" {
                    inBlockComment = true
                    index = line.index(after: next)
                    continue
                }
            }

            result.append(character)
            index = next
        }

        return result
    }
}
