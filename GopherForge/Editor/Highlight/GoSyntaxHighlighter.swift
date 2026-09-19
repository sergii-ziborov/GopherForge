import Foundation

/// Tokenises Go source for display.
///
/// A single forward pass, no regular expressions, and no attempt to parse: the
/// editor runs this on every keystroke, and correctness here means "never
/// mislabels a string or a comment", not "understands the program".
struct GoSyntaxHighlighter: Sendable {
    func tokens(in source: String) -> [GoToken] {
        var tokens: [GoToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if character == "/", let comment = scanComment(source, from: index) {
                tokens.append(comment)
                index = comment.range.upperBound
                continue
            }

            if character == "\"" || character == "`" || character == "'" {
                let string = scanString(source, from: index, terminator: character)
                tokens.append(string)
                index = string.range.upperBound
                continue
            }

            if character.isNumber {
                let number = scanNumber(source, from: index)
                tokens.append(number)
                index = number.range.upperBound
                continue
            }

            if GoLexicon.isIdentifierStart(character) {
                let identifier = scanIdentifier(source, from: index)
                tokens.append(identifier)
                index = identifier.range.upperBound
                continue
            }

            index = source.index(after: index)
        }

        return tokens
    }

    // MARK: - Scanners

    /// Handles `//` to end of line and `/* */`, including an unterminated block
    /// comment, which is what the buffer looks like mid-typing.
    private func scanComment(_ source: String, from start: String.Index) -> GoToken? {
        let next = source.index(after: start)
        guard next < source.endIndex else { return nil }

        if source[next] == "/" {
            let end = source[start...].firstIndex(of: "\n") ?? source.endIndex
            return GoToken(range: start..<end, kind: .comment)
        }

        guard source[next] == "*" else { return nil }
        var index = source.index(after: next)
        while index < source.endIndex {
            if source[index] == "*" {
                let after = source.index(after: index)
                if after < source.endIndex, source[after] == "/" {
                    return GoToken(range: start..<source.index(after: after), kind: .comment)
                }
            }
            index = source.index(after: index)
        }
        return GoToken(range: start..<source.endIndex, kind: .comment)
    }

    /// Interpreted strings honour backslash escapes; raw strings in backticks do
    /// not, and may span lines.
    private func scanString(
        _ source: String,
        from start: String.Index,
        terminator: Character
    ) -> GoToken {
        var index = source.index(after: start)
        let honoursEscapes = terminator != "`"

        while index < source.endIndex {
            let character = source[index]
            if honoursEscapes, character == "\\" {
                index = source.index(index, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                continue
            }
            if character == terminator {
                return GoToken(range: start..<source.index(after: index), kind: .string)
            }
            if honoursEscapes, character == "\n" {
                // An unterminated interpreted string ends at the newline, so a
                // half-typed line does not colour the rest of the file.
                return GoToken(range: start..<index, kind: .string)
            }
            index = source.index(after: index)
        }
        return GoToken(range: start..<source.endIndex, kind: .string)
    }

    private func scanNumber(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex {
            let character = source[index]
            let isNumeric = character.isHexDigit
                || character == "."
                || character == "_"
                || character == "x"
                || character == "o"
                || character == "b"
            guard isNumeric else { break }
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: .number)
    }

    private func scanIdentifier(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex, GoLexicon.isIdentifierBody(source[index]) {
            index = source.index(after: index)
        }
        let text = String(source[start..<index])
        return GoToken(range: start..<index, kind: kind(for: text, in: source, endingAt: index))
    }

    private func kind(
        for text: String,
        in source: String,
        endingAt index: String.Index
    ) -> GoTokenKind {
        if GoLexicon.keywords.contains(text) { return .keyword }
        if GoLexicon.predeclared.contains(text) { return .type }
        // `fmt.Println` — the qualifier before a dot reads as a package.
        if index < source.endIndex, source[index] == "." {
            return GoLexicon.commonPackages.contains(text) ? .package : .plain
        }
        if index < source.endIndex, source[index] == "(" { return .function }
        return .plain
    }
}
