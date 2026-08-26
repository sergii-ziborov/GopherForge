import Foundation

/// Turns a Go runtime failure into something teachable.
///
/// A panic, a nil map write and a deadlock all arrive as guest stderr. They are
/// among the most valuable teaching moments the product has, so they are read
/// deliberately instead of being shown as an interpreter trap.
enum GoRuntimeFailureReader {
    private static let signatures: [(needle: String, summary: String, tag: String)] = [
        (
            "all goroutines are asleep - deadlock!",
            "Every goroutine is blocked, so the program can never make progress.",
            GoConcept.deadlock
        ),
        (
            "send on closed channel",
            "A value was sent on a channel that was already closed.",
            GoConcept.channelClose
        ),
        (
            "close of closed channel",
            "The same channel was closed twice.",
            GoConcept.channelClose
        ),
        (
            "assignment to entry in nil map",
            "A map has to be made before a key can be written to it.",
            GoConcept.mapZeroValue
        ),
        (
            "index out of range",
            "A slice or array was indexed past its length.",
            GoConcept.sliceBounds
        ),
        (
            "invalid memory address or nil pointer dereference",
            "A nil pointer or nil interface value was used.",
            GoConcept.nilInterface
        ),
    ]

    static func describe(stderr: String) -> String? {
        signature(in: stderr)?.summary
    }

    static func diagnostics(stderr: String) -> [GoDiagnostic] {
        guard let signature = signature(in: stderr) else { return [] }
        return [
            GoDiagnostic(
                level: "error",
                message: signature.summary,
                origin: .compiler,
                rendered: firstPanicLine(in: stderr) ?? signature.summary,
                span: nil,
                conceptTag: signature.tag
            )
        ]
    }

    private static func signature(in stderr: String) -> (needle: String, summary: String, tag: String)? {
        let lowered = stderr.lowercased()
        return signatures.first { lowered.contains($0.needle) }
    }

    private static func firstPanicLine(in stderr: String) -> String? {
        stderr
            .split(separator: "\n")
            .first { $0.hasPrefix("panic:") || $0.hasPrefix("fatal error:") }
            .map(String.init)
    }
}
