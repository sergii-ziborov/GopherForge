import Foundation

/// The rules the idiom coach ships with.
///
/// Each one comes from a pattern the Go community documents explicitly, and
/// each explains itself in the words a reviewer would use. Nothing here guesses
/// at correctness: these are all readability and ownership conventions that a
/// compiler will happily accept either way.
enum IdiomRuleCatalog {
    static let all: [IdiomRule] = [
        contextFirstParameter,
        errorCheckedNotIgnored,
        earlyReturnOverNesting,
        senderClosesChannel,
        gettersWithoutGetPrefix,
        errorStringsStayLowercase,
    ]

    static func rule(id: String) -> IdiomRule? {
        all.first { $0.id == id }
    }

    // MARK: - Rules

    /// `context.Context` belongs first, and is never stored in a struct.
    static let contextFirstParameter = IdiomRule(
        id: "context-first-parameter",
        conceptTag: GoConcept.contextFirstParameter,
        title: "Put context.Context first",
        explanation: """
        Go's convention is that a function taking a context accepts it as the \
        first parameter, conventionally named ctx. Callers then read \
        cancellation as part of the call's shape rather than hunting for it in \
        the argument list.
        """,
        confidence: .certain,
        match: { line, context in
            guard context.isInsideFunction == false,
                  line.contains("func "),
                  line.contains("context.Context"),
                  let parameters = parameterList(in: line),
                  let contextIndex = parameterIndex(of: "context.Context", in: parameters),
                  contextIndex > 0
            else {
                return nil
            }
            return .flagOnly
        }
    )

    /// An error assigned to `_` is a decision, and it should be a visible one.
    static let errorCheckedNotIgnored = IdiomRule(
        id: "error-not-discarded",
        conceptTag: GoConcept.explicitErrorCheck,
        title: "Don't discard this error",
        explanation: """
        Assigning an error to _ silently accepts every failure this call can \
        report. If ignoring it is genuinely right, say so in a comment so the \
        next reader knows it was a decision rather than an oversight.
        """,
        confidence: .likely,
        match: { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("_ =") || trimmed.contains(", _ :=") || trimmed.contains(", _ =") else {
                return nil
            }
            guard trimmed.contains("err") == false, looksLikeCall(trimmed) else { return nil }
            return .flagOnly
        }
    )

    /// `if err != nil { return }` reads better than wrapping the happy path.
    static let earlyReturnOverNesting = IdiomRule(
        id: "early-return-over-nesting",
        conceptTag: GoConcept.explicitErrorCheck,
        title: "Return early instead of nesting",
        explanation: """
        Go code keeps the successful path at the left margin. Handling the \
        error first and returning lets the rest of the function read as the \
        thing it actually does.
        """,
        confidence: .likely,
        match: { line, context in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("if err == nil {") else { return nil }
            // Only suggest the inversion when the else branch is the error
            // path; otherwise the nesting may be carrying real logic.
            guard context.nextLine.isEmpty == false else { return nil }
            return .replace(with: "\(context.indentation)if err != nil {")
        }
    )

    /// Only the sender may close a channel.
    static let senderClosesChannel = IdiomRule(
        id: "sender-closes-channel",
        conceptTag: GoConcept.channelClose,
        title: "Only the sender should close this channel",
        explanation: """
        A receiver that closes a channel races with every sender still holding \
        it. Ownership of close belongs to the goroutine that owns sending, \
        which is what lets receivers use range and comma-ok safely.
        """,
        confidence: .likely,
        match: { line, context in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("close(") else { return nil }
            // A close directly after a receive is the shape that is almost
            // always wrong: this goroutine is reading, not sending.
            let previous = context.previousLine.trimmingCharacters(in: .whitespaces)
            guard isReceive(previous) else { return nil }
            return .flagOnly
        }
    )

    /// Go getters are named `Owner()`, not `GetOwner()`.
    static let gettersWithoutGetPrefix = IdiomRule(
        id: "getter-without-get-prefix",
        conceptTag: GoConcept.smallInterface,
        title: "Drop the Get prefix",
        explanation: """
        Go names a getter after the thing it returns: Owner() rather than \
        GetOwner(). The Get prefix is a Java and C# habit that reads as noise \
        at the call site.
        """,
        confidence: .certain,
        match: { line, _ in
            guard let range = line.range(of: #"func \(\w+ \*?\w+\) Get[A-Z]\w*\("#, options: .regularExpression) else {
                return nil
            }
            let replacement = line.replacingCharacters(
                in: range,
                with: String(line[range]).replacingOccurrences(of: ") Get", with: ") ")
            )
            return .replace(with: replacement)
        }
    )

    /// Error strings are lowercase and unpunctuated, because they get wrapped.
    static let errorStringsStayLowercase = IdiomRule(
        id: "error-string-style",
        conceptTag: GoConcept.errorWrapping,
        title: "Error strings start lowercase",
        explanation: """
        Error strings are concatenated into larger sentences by the code that \
        wraps them, so they start lowercase and end without punctuation.
        """,
        confidence: .certain,
        match: { line, _ in
            guard let range = line.range(
                of: #"(errors\.New|fmt\.Errorf)\("[A-Z]"#,
                options: .regularExpression
            ) else {
                return nil
            }
            let matched = String(line[range])
            guard let quoteIndex = matched.firstIndex(of: "\"") else { return nil }
            let letterIndex = matched.index(after: quoteIndex)
            let lowered = matched.replacingCharacters(
                in: letterIndex...letterIndex,
                with: matched[letterIndex].lowercased()
            )
            return .replace(with: line.replacingCharacters(in: range, with: lowered))
        }
    )

    // MARK: - Shared line reading

    private static func parameterList(in line: String) -> String? {
        guard let open = line.firstIndex(of: "("),
              let close = line[open...].firstIndex(of: ")")
        else {
            return nil
        }
        return String(line[line.index(after: open)..<close])
    }

    private static func parameterIndex(of type: String, in parameters: String) -> Int? {
        parameters
            .split(separator: ",")
            .firstIndex { $0.contains(type) }
    }

    private static func looksLikeCall(_ line: String) -> Bool {
        line.contains("(") && line.contains(")")
    }

    private static func isReceive(_ line: String) -> Bool {
        guard let arrow = line.range(of: "<-") else { return false }
        let before = line[line.startIndex..<arrow.lowerBound].trimmingCharacters(in: .whitespaces)
        // `x := <-ch` and `range ch` receive; `ch <- x` sends.
        return before.hasSuffix("=") || before.hasSuffix(":=") || before.isEmpty || before.hasSuffix("range")
    }
}
