import SwiftUI

/// Colours one line of console output.
///
/// A console that prints everything in one grey is a console you have to read
/// word by word to find the thing that went wrong. Three shapes carry almost
/// all of the meaning here: the command you typed, a diagnostic with a file and
/// a position, and a test result. Everything else stays plain, because
/// colouring what has no meaning is worse than colouring nothing.
enum TerminalLineStyle {
    // Kept concrete for the named captures, and immutable, so `nonisolated` is
    // safe — see GoDiagnosticParser for the same note.
    nonisolated(unsafe) private static let diagnostic =
        /^(?<file>[^\s:]+\.go):(?<line>\d+)(?::(?<column>\d+))?:\s*(?<message>.*)$/
    nonisolated(unsafe) private static let testResult =
        /^(?<mark>ok|FAIL|---\s+(?:PASS|FAIL|SKIP)|PASS)\b(?<rest>.*)$/

    static func attributed(_ text: String, kind: ProjectTerminalSession.Entry.Kind) -> AttributedString {
        var out = AttributedString()
        let lines = text.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            out += styled(line, kind: kind)
            if index < lines.count - 1 { out += AttributedString("\n") }
        }
        return out
    }

    private static func styled(
        _ line: String,
        kind: ProjectTerminalSession.Entry.Kind
    ) -> AttributedString {
        if kind == .command { return command(line) }
        if let match = line.firstMatch(of: diagnostic) {
            return diagnosticLine(
                file: String(match.output.file),
                position: String(match.output.line)
                    + (match.output.column.map { ":\($0)" } ?? ""),
                message: String(match.output.message)
            )
        }
        if let match = line.firstMatch(of: testResult) {
            let mark = String(match.output.mark)
            var head = AttributedString(mark)
            head.foregroundColor = mark.contains("FAIL") ? .red : .green
            head.font = .caption.monospaced().weight(.semibold)
            var rest = AttributedString(String(match.output.rest))
            rest.foregroundColor = kind == .failure ? .red : .primary
            return head + rest
        }

        var plain = AttributedString(line)
        plain.foregroundColor = kind == .failure ? .red : .primary
        return plain
    }

    /// `$ go build` — the prompt dim, the tool in the app's own colour, the
    /// rest ordinary, so the eye finds the last command in a long transcript.
    private static func command(_ line: String) -> AttributedString {
        let body = line.hasPrefix("$ ") ? String(line.dropFirst(2)) : line
        var prompt = AttributedString(line.hasPrefix("$ ") ? "$ " : "")
        prompt.foregroundColor = .secondary

        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        var tool = AttributedString(String(parts.first ?? ""))
        tool.foregroundColor = GopherForgeTheme.ember
        tool.font = .caption.monospaced().weight(.semibold)

        guard parts.count > 1 else { return prompt + tool }
        var rest = AttributedString(" " + String(parts[1]))
        rest.foregroundColor = .primary
        return prompt + tool + rest
    }

    private static func diagnosticLine(
        file: String,
        position: String,
        message: String
    ) -> AttributedString {
        var path = AttributedString(file)
        path.foregroundColor = .teal
        var where_ = AttributedString(":\(position): ")
        where_.foregroundColor = .secondary
        var text = AttributedString(message)
        text.foregroundColor = .orange
        return path + where_ + text
    }
}
