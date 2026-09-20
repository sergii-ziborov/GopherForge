import Foundation

/// Tokenises CSS: comments, at-rules, property names, strings and numbers.
struct CSSSyntaxHighlighter: Sendable {
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

            if character == "\"" || character == "'" {
                let string = scanString(source, from: index, terminator: character)
                tokens.append(string)
                index = string.range.upperBound
                continue
            }

            if character == "#" || character.isNumber {
                let number = scanHashOrNumber(source, from: index)
                tokens.append(number)
                index = number.range.upperBound
                continue
            }

            if character == "@" {
                let rule = scanIdent(source, from: index, kind: .keyword)
                tokens.append(rule)
                index = rule.range.upperBound
                continue
            }

            if character.isLetter || character == "-" || character == "_" {
                let word = scanPropertyOrSelector(source, from: index)
                tokens.append(word)
                index = word.range.upperBound
                continue
            }

            index = source.index(after: index)
        }

        return tokens
    }

    private func scanComment(_ source: String, from start: String.Index) -> GoToken? {
        let next = source.index(after: start)
        guard next < source.endIndex, source[next] == "*" else { return nil }
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

    private func scanString(
        _ source: String,
        from start: String.Index,
        terminator: Character
    ) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex {
            if source[index] == "\\" {
                index = source.index(index, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                continue
            }
            if source[index] == terminator {
                return GoToken(range: start..<source.index(after: index), kind: .string)
            }
            index = source.index(after: index)
        }
        return GoToken(range: start..<source.endIndex, kind: .string)
    }

    private func scanHashOrNumber(_ source: String, from start: String.Index) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex {
            let character = source[index]
            guard character.isHexDigit || character == "." || character == "%" else { break }
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: .number)
    }

    private func scanIdent(
        _ source: String,
        from start: String.Index,
        kind: GoTokenKind
    ) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex, isIdent(source[index]) {
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: kind)
    }

    private func scanPropertyOrSelector(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex, isIdent(source[index]) {
            index = source.index(after: index)
        }
        var look = index
        while look < source.endIndex, source[look] == " " || source[look] == "\t" {
            look = source.index(after: look)
        }
        let kind: GoTokenKind = look < source.endIndex && source[look] == ":" ? .directive : .type
        return GoToken(range: start..<index, kind: kind)
    }

    private func isIdent(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "_"
    }
}
