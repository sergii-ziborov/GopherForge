import Foundation

/// Deterministic, offline Go completions.
///
/// This is the floor the product guarantees: it works on every device, in
/// airplane mode, with no model available. Suggestions are the shapes Go
/// repeats constantly, which is exactly what someone moving from another
/// language types most slowly.
struct GoCodeCompletion: Sendable {
    struct Context: Sendable {
        let line: String
        let indentation: String
        let fileKind: SourceFileKind

        init(line: String, fileKind: SourceFileKind = .go) {
            self.line = line
            self.fileKind = fileKind
            indentation = String(line.prefix { $0 == " " || $0 == "\t" })
        }

        var trimmed: String { line.trimmingCharacters(in: .whitespaces) }
    }

    func suggestions(for context: Context) -> [GoCompletionSuggestion] {
        guard context.fileKind == .go else { return moduleSuggestions(for: context) }
        return Self.templates
            .filter { $0.matches(context.trimmed) }
            .map { $0.suggestion(indentation: context.indentation) }
    }

    private func moduleSuggestions(for context: Context) -> [GoCompletionSuggestion] {
        guard context.fileKind == .goMod, context.trimmed.isEmpty == false else { return [] }
        guard "require".hasPrefix(context.trimmed) else { return [] }
        return [
            GoCompletionSuggestion(
                title: "require block",
                detail: "A parenthesised require with one dependency",
                insertion: "require (\n\t\n)",
                origin: .bundled,
                conceptTag: GoConcept.importPath
            )
        ]
    }
}

private extension GoCodeCompletion {
    struct Template {
        let trigger: String
        let title: String
        let detail: String
        let conceptTag: String?
        let body: (String) -> String

        func matches(_ trimmed: String) -> Bool {
            !trimmed.isEmpty && trigger.hasPrefix(trimmed)
        }

        func suggestion(indentation: String) -> GoCompletionSuggestion {
            GoCompletionSuggestion(
                title: title,
                detail: detail,
                insertion: body(indentation),
                origin: .bundled,
                conceptTag: conceptTag
            )
        }
    }

    static let templates: [Template] = [
        Template(
            trigger: "iferr",
            title: "if err != nil",
            detail: "The error check, returning the wrapped error",
            conceptTag: GoConcept.explicitErrorCheck,
            body: { indent in
                "if err != nil {\n\(indent)\treturn fmt.Errorf(\": %w\", err)\n\(indent)}"
            }
        ),
        Template(
            trigger: "forrange",
            title: "for … range",
            detail: "Range loop over a slice or map",
            conceptTag: GoConcept.sliceAliasing,
            body: { indent in
                "for index, value := range collection {\n\(indent)\t_ = index\n\(indent)\t_ = value\n\(indent)}"
            }
        ),
        Template(
            trigger: "commaok",
            title: "value, ok := m[key]",
            detail: "Distinguish an absent key from a zero value",
            conceptTag: GoConcept.mapZeroValue,
            body: { indent in
                "value, ok := lookup[key]\n\(indent)if !ok {\n\(indent)\t\n\(indent)}"
            }
        ),
        Template(
            trigger: "select",
            title: "select with cancellation",
            detail: "Wait on a value or on ctx.Done",
            conceptTag: GoConcept.selectBranch,
            body: { indent in
                "select {\n\(indent)case value := <-values:\n\(indent)\t_ = value\n"
                    + "\(indent)case <-ctx.Done():\n\(indent)\treturn ctx.Err()\n\(indent)}"
            }
        ),
        Template(
            trigger: "gofunc",
            title: "go func with WaitGroup",
            detail: "A goroutine that signals completion",
            conceptTag: GoConcept.waitGroup,
            body: { indent in
                "workers.Add(1)\n\(indent)go func() {\n\(indent)\tdefer workers.Done()\n\(indent)\t\n\(indent)}()"
            }
        ),
        Template(
            trigger: "tablecase",
            title: "table-driven test",
            detail: "Cases as data, assertion as code",
            conceptTag: GoConcept.stdlibTesting,
            body: { indent in
                "cases := []struct {\n\(indent)\tname string\n\(indent)\twant int\n\(indent)}{\n"
                    + "\(indent)\t{name: \"\", want: 0},\n\(indent)}\n"
                    + "\(indent)for _, testCase := range cases {\n"
                    + "\(indent)\tt.Run(testCase.name, func(t *testing.T) {\n\(indent)\t\t\n\(indent)\t})\n\(indent)}"
            }
        ),
        Template(
            trigger: "defclose",
            title: "defer close",
            detail: "Close owned by the sender, on every path",
            conceptTag: GoConcept.channelClose,
            body: { indent in "defer close(out)" }
        ),
    ]
}
