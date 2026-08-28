import Foundation

/// Finds a file by its name, or by something inside it.
///
/// Results are grouped by file rather than listed flat. A file whose name
/// matches almost always contains the word too — `main.go` holds `func main` —
/// and a flat list shows that file once for its name and again for every line,
/// which reads as the search repeating itself. One file is one result, however
/// many ways it matched.
///
/// Everything runs over the project already in memory, so there is nothing to
/// index and nothing to keep in sync.
enum ProjectFileSearch {
    /// A hit inside a file, at a 1-based line number.
    struct Line: Identifiable, Equatable, Sendable {
        let number: Int
        let snippet: String

        var id: Int { number }
    }

    /// Everything one file matched.
    struct FileResult: Identifiable, Equatable, Sendable {
        let path: String
        /// The path itself contains the query.
        let matchesName: Bool
        let lines: [Line]
        /// Hits this file has beyond the ones listed. Shown rather than
        /// dropped silently, so a capped result never looks like a complete
        /// one.
        let additionalLines: Int

        var id: String { path }

        /// What the row says it found, in the fewest words that stay true.
        var summary: String {
            let total = lines.count + additionalLines
            if total == 0 { return "file name" }
            let hits = "\(total) line\(total == 1 ? "" : "s")"
            return matchesName ? "name · \(hits)" : hits
        }
    }

    /// Caps chosen so a long file cannot fill the list with one file's hits and
    /// a broad query cannot make the sidebar unusable.
    static let maximumLinesPerFile = 4
    static let maximumFiles = 40
    /// Content is only searched once a query is worth searching for: one letter
    /// matches everything and tells the reader nothing.
    static let minimumContentQueryLength = 2

    static func results(query: String, in files: [String: String]) -> [FileResult] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }

        let searchesContent = needle.count >= minimumContentQueryLength
        var found: [FileResult] = []

        for path in files.keys.sorted() {
            let matchesName = path.lowercased().contains(needle)
            let (lines, extra) = searchesContent
                ? contentMatches(needle: needle, source: files[path] ?? "")
                : ([], 0)
            guard matchesName || !lines.isEmpty else { continue }

            found.append(
                FileResult(
                    path: path,
                    matchesName: matchesName,
                    lines: lines,
                    additionalLines: extra
                )
            )
        }

        // A file whose name matches is almost always the one that was meant,
        // so it is listed before files that merely mention the word.
        let ordered = found.sorted { left, right in
            if left.matchesName != right.matchesName { return left.matchesName }
            return left.path < right.path
        }
        return Array(ordered.prefix(maximumFiles))
    }

    private static func contentMatches(
        needle: String,
        source: String
    ) -> (lines: [Line], additional: Int) {
        var lines: [Line] = []
        var additional = 0

        for (index, line) in source.components(separatedBy: "\n").enumerated()
        where line.lowercased().contains(needle) {
            guard lines.count < maximumLinesPerFile else {
                additional += 1
                continue
            }
            lines.append(Line(number: index + 1, snippet: snippet(of: line)))
        }

        return (lines, additional)
    }

    /// Trimmed and shortened, because a sidebar row shows one line and a long
    /// one would push the file name off the edge.
    static func snippet(of line: String, limit: Int = 70) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

    /// Every case-insensitive occurrence of `query` inside `text`.
    ///
    /// Shared by the sidebar snippet and the editor so a match is marked the
    /// same way in both places, and so the highlighting can never disagree with
    /// what the search actually matched.
    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text.range(
                  of: needle,
                  options: .caseInsensitive,
                  range: searchStart..<text.endIndex
              ) {
            ranges.append(found)
            // Advance by one character rather than to the end of the match, so
            // overlapping occurrences ("aa" in "aaa") are all marked.
            searchStart = text.index(after: found.lowerBound)
        }
        return ranges
    }
}
