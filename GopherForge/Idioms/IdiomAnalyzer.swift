import Foundation

/// Runs the idiom rules over a project snapshot.
///
/// This is a line-shaped analyzer on purpose: it runs on every keystroke pause,
/// offline, without the toolchain, and must never be the reason typing feels
/// slow. Anything that needs a real type graph belongs to `go vet`, which the
/// app runs separately and reports as a different origin.
struct IdiomAnalyzer: Sendable {
    private let rules: [IdiomRule]

    init(rules: [IdiomRule] = IdiomRuleCatalog.all) {
        self.rules = rules
    }

    func analyze(_ snapshot: GoSourceSnapshot) -> [IdiomFinding] {
        snapshot.files
            .filter { $0.key.hasSuffix(".go") }
            .sorted { $0.key < $1.key }
            .flatMap { analyze(source: $0.value, fileName: $0.key) }
    }

    func analyze(source: String, fileName: String) -> [IdiomFinding] {
        let lines = source.components(separatedBy: "\n")
        var findings: [IdiomFinding] = []
        var depth = 0

        for (index, line) in lines.enumerated() {
            let context = IdiomRuleContext(
                fileName: fileName,
                lineNumber: index + 1,
                previousLine: index > 0 ? lines[index - 1] : "",
                nextLine: index + 1 < lines.count ? lines[index + 1] : "",
                indentation: Self.indentation(of: line),
                isInsideFunction: depth > 0
            )

            if Self.isSkippable(line) {
                depth += Self.depthChange(in: line)
                continue
            }

            for rule in rules {
                guard let match = rule.match(line, context) else { continue }
                findings.append(
                    IdiomFinding(
                        ruleID: rule.id,
                        conceptTag: rule.conceptTag,
                        title: rule.title,
                        explanation: rule.explanation,
                        fileName: fileName,
                        line: context.lineNumber,
                        confidence: rule.confidence,
                        suggestedReplacement: match.suggestedReplacement
                    )
                )
            }

            depth += Self.depthChange(in: line)
        }

        return findings
    }

    /// Comments and empty lines carry no idioms, and a rule that fired inside a
    /// comment would be indistinguishable from noise.
    private static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("//")
    }

    private static func depthChange(in line: String) -> Int {
        line.count { $0 == "{" } - line.count { $0 == "}" }
    }

    private static func indentation(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }
}
