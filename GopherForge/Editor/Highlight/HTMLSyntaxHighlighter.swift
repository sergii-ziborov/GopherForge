import Foundation

/// Tokenises HTML for the editor.
///
/// A single forward pass: comments, tags, attribute names and quoted values.
/// Script and style bodies stay plain so a half-typed page never paints the
/// rest of the file as a string.
struct HTMLSyntaxHighlighter: Sendable {
    func tokens(in source: String) -> [GoToken] {
        var tokens: [GoToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index] == "<" {
                if let comment = scanComment(source, from: index) {
                    tokens.append(comment)
                    index = comment.range.upperBound
                    continue
                }
                let scanned = scanTag(source, from: index)
                tokens.append(contentsOf: scanned.tokens)
                index = scanned.end
                continue
            }
            index = source.index(after: index)
        }

        return tokens
    }

    private func scanComment(_ source: String, from start: String.Index) -> GoToken? {
        let rest = source[start...]
        guard rest.hasPrefix("<!--") else { return nil }
        if let end = rest.range(of: "-->") {
            return GoToken(range: start..<end.upperBound, kind: .comment)
        }
        return GoToken(range: start..<source.endIndex, kind: .comment)
    }

    private func scanTag(
        _ source: String,
        from start: String.Index
    ) -> (tokens: [GoToken], end: String.Index) {
        var tokens: [GoToken] = []
        var index = source.index(after: start)
        if index < source.endIndex, source[index] == "/" || source[index] == "!" {
            index = source.index(after: index)
        }

        let nameStart = index
        while index < source.endIndex, isName(source[index]) {
            index = source.index(after: index)
        }
        if nameStart < index {
            tokens.append(GoToken(range: nameStart..<index, kind: .keyword))
        }

        while index < source.endIndex {
            let character = source[index]
            if character == ">" {
                return (tokens, source.index(after: index))
            }
            if character == "/", source.index(after: index) < source.endIndex,
               source[source.index(after: index)] == ">" {
                return (tokens, source.index(index, offsetBy: 2))
            }
            if character == "\"" || character == "'" {
                let string = scanQuoted(source, from: index, terminator: character)
                tokens.append(string)
                index = string.range.upperBound
                continue
            }
            if isName(character) {
                let attrStart = index
                while index < source.endIndex, isName(source[index]) || source[index] == "-" {
                    index = source.index(after: index)
                }
                tokens.append(GoToken(range: attrStart..<index, kind: .package))
                continue
            }
            index = source.index(after: index)
        }

        return (tokens, index)
    }

    private func scanQuoted(
        _ source: String,
        from start: String.Index,
        terminator: Character
    ) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex {
            if source[index] == terminator {
                return GoToken(range: start..<source.index(after: index), kind: .string)
            }
            index = source.index(after: index)
        }
        return GoToken(range: start..<source.endIndex, kind: .string)
    }

    private func isName(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
