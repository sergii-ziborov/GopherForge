import Foundation

/// A single compiler, vet or format finding, normalised to one location.
///
/// Go reports diagnostics as plain text (`file:line:col: message`) rather than
/// as structured JSON, so unlike a Rust diagnostic there is no span list and no
/// stable numeric code. The app therefore carries its own `conceptTag` and
/// never presents it as something the toolchain emitted.
struct GoDiagnostic: Identifiable, Equatable, Sendable {
    struct Span: Equatable, Sendable {
        let fileName: String
        let line: Int
        let column: Int
        let sourceLine: String

        init(
            fileName: String = "main.go",
            line: Int,
            column: Int,
            sourceLine: String = ""
        ) {
            self.fileName = fileName
            self.line = line
            self.column = column
            self.sourceLine = sourceLine
        }
    }

    /// A vet finding never blocks a build, and the learning path treats the
    /// two as different kinds of evidence, so the origin stays explicit.
    enum Origin: String, Sendable {
        case compiler
        case vet
        case format
    }

    let id = UUID()
    let level: String
    let message: String
    let origin: Origin
    let rendered: String
    let span: Span?
    let conceptTag: String?

    var isBlocking: Bool {
        origin == .compiler && level == "error"
    }
}

extension GoDiagnostic {
    func appendingContinuation(_ continuation: String) -> GoDiagnostic {
        GoDiagnostic(
            level: level,
            message: message,
            origin: origin,
            rendered: rendered + "\n\t" + continuation,
            span: span,
            conceptTag: conceptTag
        )
    }
}
