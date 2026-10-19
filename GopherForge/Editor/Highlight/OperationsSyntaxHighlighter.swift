import Foundation

/// Lightweight lexical colouring for command and manifest examples, not a validator.
/// Strings/comments claim their ranges first so flags and keys inside them stay text.
struct OperationsSyntaxHighlighter: Sendable {
    enum Language { case shell, yaml, dockerfile }
    let language: Language

    func tokens(in source: String) -> [GoToken] {
        let ns = source as NSString
        var claimed = IndexSet()
        var result: [GoToken] = []
        func match(_ pattern: String, kind: GoTokenKind, group: Int = 0) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for item in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
                let range = item.range(at: group)
                guard range.length > 0, !claimed.intersects(integersIn: range.location..<NSMaxRange(range)),
                      let swiftRange = Range(range, in: source) else { continue }
                result.append(GoToken(range: swiftRange, kind: kind))
                claimed.insert(integersIn: range.location..<NSMaxRange(range))
            }
        }
        // One combined pass prevents a # inside quotes becoming a comment and
        // prevents a quote in a comment opening a string across the next line.
        let protected = #"(?m)"(?:\\.|[^"\\\n])*"|'[^'\n]*'|(?:^|(?<=\s))#[^\n]*"#
        if let regex = try? NSRegularExpression(pattern: protected) {
            for item in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
                guard let range = Range(item.range, in: source) else { continue }
                let text = source[range]
                result.append(GoToken(range: range, kind: text.first == "#" ? .comment : .string))
                claimed.insert(integersIn: item.range.location..<NSMaxRange(item.range))
            }
        }
        switch language {
        case .shell:
            match(#"\$(?:\{[^}\n]*\}|[A-Za-z_][A-Za-z_0-9]*|[!@?#0-9])"#, kind: .type)
            match(#"(?<![\w-])--?[A-Za-z][A-Za-z0-9-]*"#, kind: .directive)
            match(#"\b(?:if|then|else|elif|fi|for|do|done|while|in|case|esac|function)\b"#, kind: .keyword)
            match(#"\b(?:pwd|cd|ls|mkdir|mktemp|cp|mv|cat|rm|rmdir|find|grep|head|tail|sort|uniq|wc|cmp|printf|read|export|unset|set|trap|exit|wait|kill|ps|lsof|tee|go|gofmt|git|curl|docker|podman|kubectl|systemctl|journalctl|sudo|bash|command)\b"#, kind: .function)
        case .yaml:
            match(#"(?:^|[\s{,])([A-Za-z_][\w.-]*)(?=:\s|:$)"#, kind: .directive, group: 1)
            match(#"\b(?:true|false|null)\b"#, kind: .keyword)
        case .dockerfile:
            match(#"(?mi)^\s*(FROM|AS|WORKDIR|COPY|RUN|USER|EXPOSE|ENTRYPOINT|CMD|ENV|ARG|LABEL|HEALTHCHECK|STOPSIGNAL|VOLUME)\b"#, kind: .keyword, group: 1)
            match(#"(?<![\w-])--[A-Za-z][A-Za-z0-9-]*"#, kind: .directive)
        }
        match(#"(?<![\w])\d+(?:\.\d+)?(?:Mi|Gi|m)?\b"#, kind: .number)
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
