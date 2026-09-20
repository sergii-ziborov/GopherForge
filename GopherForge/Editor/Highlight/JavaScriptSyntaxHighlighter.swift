import Foundation

/// Tokenises JavaScript the same way the Go highlighter tokenises Go: one
/// forward pass, comments and strings first, then numbers and words.
struct JavaScriptSyntaxHighlighter: Sendable {
    private static let keywords: Set<String> = [
        "break", "case", "catch", "class", "const", "continue", "debugger",
        "default", "delete", "do", "else", "export", "extends", "false",
        "finally", "for", "function", "if", "import", "in", "instanceof",
        "let", "new", "null", "return", "super", "switch", "this", "throw",
        "true", "try", "typeof", "var", "void", "while", "with", "yield",
        "async", "await", "of", "static",
    ]

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

            if character == "\"" || character == "'" || character == "`" {
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

            if character.isLetter || character == "_" || character == "$" {
                let word = scanWord(source, from: index)
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

    private func scanString(
        _ source: String,
        from start: String.Index,
        terminator: Character
    ) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex {
            let character = source[index]
            if character == "\\" {
                index = source.index(index, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                continue
            }
            if character == terminator {
                return GoToken(range: start..<source.index(after: index), kind: .string)
            }
            if terminator != "`", character == "\n" {
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
            guard character.isHexDigit || character == "." || character == "_"
                    || character == "x" || character == "o" || character == "b"
            else { break }
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: .number)
    }

    private func scanWord(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex {
            let character = source[index]
            guard character.isLetter || character.isNumber || character == "_" || character == "$"
            else { break }
            index = source.index(after: index)
        }
        let text = String(source[start..<index])
        let kind: GoTokenKind
        if Self.keywords.contains(text) {
            kind = .keyword
        } else if index < source.endIndex, source[index] == "(" {
            kind = .function
        } else {
            kind = .plain
        }
        return GoToken(range: start..<index, kind: kind)
    }
}

/// Tokenises JSON: strings, numbers, and the three reserved words.
struct JSONSyntaxHighlighter: Sendable {
    func tokens(in source: String) -> [GoToken] {
        var tokens: [GoToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if character == "\"" {
                let string = scanString(source, from: index)
                tokens.append(string)
                index = string.range.upperBound
                continue
            }
            if character.isNumber || character == "-" {
                let number = scanNumber(source, from: index)
                tokens.append(number)
                index = number.range.upperBound
                continue
            }
            if character.isLetter {
                let word = scanWord(source, from: index)
                tokens.append(word)
                index = word.range.upperBound
                continue
            }
            index = source.index(after: index)
        }

        return tokens
    }

    private func scanString(_ source: String, from start: String.Index) -> GoToken {
        var index = source.index(after: start)
        while index < source.endIndex {
            if source[index] == "\\" {
                index = source.index(index, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                continue
            }
            if source[index] == "\"" {
                return GoToken(range: start..<source.index(after: index), kind: .string)
            }
            index = source.index(after: index)
        }
        return GoToken(range: start..<source.endIndex, kind: .string)
    }

    private func scanNumber(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        if source[index] == "-" { index = source.index(after: index) }
        while index < source.endIndex {
            let character = source[index]
            guard character.isNumber || character == "." || character == "e"
                    || character == "E" || character == "+" || character == "-"
            else { break }
            index = source.index(after: index)
        }
        return GoToken(range: start..<index, kind: .number)
    }

    private func scanWord(_ source: String, from start: String.Index) -> GoToken {
        var index = start
        while index < source.endIndex, source[index].isLetter {
            index = source.index(after: index)
        }
        let text = String(source[start..<index])
        let kind: GoTokenKind = ["true", "false", "null"].contains(text) ? .keyword : .plain
        return GoToken(range: start..<index, kind: kind)
    }
}
