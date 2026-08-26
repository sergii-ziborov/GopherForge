import Foundation

/// Parses the plain-text diagnostic stream the Go toolchain writes to stderr.
///
/// The stream mixes three shapes: package banners (`# command-line-arguments`),
/// located findings (`./main.go:6:2: declared and not used: x`) and indented
/// continuation notes that belong to the finding above them.
enum GoDiagnosticParser {
    private static let locationPattern =
        /^(?<file>[^\s:][^:]*\.go):(?<line>\d+)(?::(?<column>\d+))?:\s*(?<message>.*)$/
    private static let packageBannerPattern = /^#\s+(?<package>\S+)/

    static func parse(
        stderr: String,
        origin: GoDiagnostic.Origin = .compiler,
        sourceLines: [String: [String]] = [:]
    ) -> [GoDiagnostic] {
        var diagnostics: [GoDiagnostic] = []
        var continuationTarget: Int?

        for rawLine in stderr.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if line.firstMatch(of: packageBannerPattern) != nil {
                continuationTarget = nil
                continue
            }

            if isContinuation(line) {
                if let index = continuationTarget {
                    let note = line.trimmingCharacters(in: .whitespaces)
                    diagnostics[index] = diagnostics[index].appendingContinuation(note)
                }
                continue
            }

            guard let diagnostic = diagnostic(from: line, origin: origin, sourceLines: sourceLines) else {
                continuationTarget = nil
                continue
            }

            diagnostics.append(diagnostic)
            continuationTarget = diagnostics.count - 1
        }

        return diagnostics
    }

    private static func isContinuation(_ line: String) -> Bool {
        line.hasPrefix("\t") || line.hasPrefix("    ")
    }

    private static func diagnostic(
        from line: String,
        origin: GoDiagnostic.Origin,
        sourceLines: [String: [String]]
    ) -> GoDiagnostic? {
        guard let match = line.firstMatch(of: locationPattern) else { return nil }

        let file = ProjectPathNormalizer.normalize(String(match.output.file))
        let lineNumber = Int(match.output.line) ?? 0
        let column = match.output.column.flatMap { Int($0) } ?? 0
        let message = String(match.output.message)

        return GoDiagnostic(
            level: origin == .vet ? "warning" : "error",
            message: message,
            origin: origin,
            rendered: "\(file):\(lineNumber):\(column): \(message)",
            span: GoDiagnostic.Span(
                fileName: file,
                line: lineNumber,
                column: column,
                sourceLine: sourceLine(for: file, line: lineNumber, in: sourceLines)
            ),
            conceptTag: GoConceptTagger.tag(for: message)
        )
    }

    private static func sourceLine(
        for file: String,
        line: Int,
        in sourceLines: [String: [String]]
    ) -> String {
        guard let lines = sourceLines[file], line >= 1, line <= lines.count else { return "" }
        return lines[line - 1]
    }
}

/// Toolchain output refers to files by their path inside the guest working
/// directory. The UI only ever shows project-relative paths.
enum ProjectPathNormalizer {
    static func normalize(_ rawPath: String) -> String {
        var path = rawPath.replacingOccurrences(of: "\\", with: "/")
        if let workRange = path.range(of: "/work/") {
            path = String(path[workRange.upperBound...])
        }
        while path.hasPrefix("./") { path.removeFirst(2) }
        return path
    }
}
