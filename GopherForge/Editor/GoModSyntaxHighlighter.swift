import Foundation

/// Tokenises `go.mod`.
///
/// A separate highlighter because go.mod is its own small language: directives,
/// module paths and versions, with `//` comments and no strings to speak of.
struct GoModSyntaxHighlighter: Sendable {
    private static let directives: Set<String> = [
        "module", "go", "toolchain", "require", "replace", "exclude", "retract",
    ]

    func tokens(in source: String) -> [GoToken] {
        var tokens: [GoToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if character == "/", source.index(after: index) < source.endIndex,
               source[source.index(after: index)] == "/" {
                let end = source[index...].firstIndex(of: "\n") ?? source.endIndex
                tokens.append(GoToken(range: index..<end, kind: .comment))
                index = end
                continue
            }

            if character == "v", isVersionStart(source, at: index) {
                let version = scanVersion(source, from: index)
                tokens.append(version)
                index = version.range.upperBound
                continue
            }

            if GoLexicon.isIdentifierStart(character) {
                let word = scanWord(source, from: index)
                tokens.append(word)
                index = word.range.upperBound
                continue
            }

            index = source.index(after: index)
        }

        return tokens
    }

    /// A version is `v` followed by a digit, and only at the start of a word,
    /// so the `v` in `vendor` is never mistaken for one.
    private func isVersionStart(_ source: String, at index: String.Index) -> Bool {
        if index > source.startIndex {
            let previous = source[source.index(before: index)]
            guard !GoLexicon.isIdentifierBody(previous) else { return false }
        }
        let next = source.index(after: index)
        return next < source.endIndex && source[next].isNumber
    }

    private func scanVersion(_ source: String, from start: String.Index) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex,
              source[index].isNumber || source[index] == "." || source[index] == "-"
                || source[index].isLetter || source[index] == "+" {
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: .number)
    }

    private func scanWord(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex,
              GoLexicon.isIdentifierBody(source[index]) || source[index] == "." || source[index] == "/"
                || source[index] == "-" {
            index = source.index(after: index)
        }
        let text = String(source[start..<index])
        let isAtLineStart = Self.isFirstWordOnLine(source, start: start)
        let kind: GoTokenKind = isAtLineStart && Self.directives.contains(text) ? .directive : .plain
        return GoToken(range: start..<index, kind: kind)
    }

    private static func isFirstWordOnLine(_ source: String, start: String.Index) -> Bool {
        var index = start
        while index > source.startIndex {
            index = source.index(before: index)
            let character = source[index]
            if character == "\n" { return true }
            if character != " " && character != "\t" { return false }
        }
        return true
    }
}
