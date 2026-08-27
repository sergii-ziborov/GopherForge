import Foundation

/// Finds a file by its name, or by something inside it.
///
/// Two searches rather than one, because they answer different questions and
/// deserve different answers: "where is main.go" wants a path, and "where do I
/// call Println" wants the line. Both run over the project already in memory,
/// so there is nothing to index and nothing to keep in sync.
enum ProjectFileSearch {
    struct Match: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case name
            /// A hit inside the file, at a 1-based line number.
            case content(line: Int, snippet: String)
        }

        let path: String
        let kind: Kind

        var id: String {
            switch kind {
            case .name: "name:\(path)"
            case let .content(line, _): "line:\(path):\(line)"
            }
        }

        var lineNumber: Int? {
            if case let .content(line, _) = kind { return line }
            return nil
        }
    }

    /// Caps chosen so a long file cannot fill the list with one file's hits and
    /// a broad query cannot make the sidebar unusable.
    static let maximumMatchesPerFile = 4
    static let maximumMatches = 60
    /// Content is only searched once a query is worth searching for: one letter
    /// matches everything and tells the reader nothing.
    static let minimumContentQueryLength = 2

    static func matches(query: String, in files: [String: String]) -> [Match] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }

        var found: [Match] = []
        // Names first: a file whose name matches is almost always what was
        // meant, and burying it under content hits from elsewhere is wrong.
        for path in files.keys.sorted() where path.lowercased().contains(needle) {
            found.append(Match(path: path, kind: .name))
        }

        guard needle.count >= minimumContentQueryLength else { return Array(found.prefix(maximumMatches)) }

        for path in files.keys.sorted() {
            guard found.count < maximumMatches else { break }
            found.append(contentsOf: contentMatches(needle: needle, path: path, source: files[path] ?? ""))
        }

        return Array(found.prefix(maximumMatches))
    }

    private static func contentMatches(needle: String, path: String, source: String) -> [Match] {
        var found: [Match] = []
        for (index, line) in source.components(separatedBy: "\n").enumerated() {
            guard line.lowercased().contains(needle) else { continue }
            found.append(
                Match(
                    path: path,
                    kind: .content(line: index + 1, snippet: snippet(of: line))
                )
            )
            if found.count == maximumMatchesPerFile { break }
        }
        return found
    }

    /// Trimmed and shortened, because a sidebar row shows one line and a long
    /// one would push the file name off the edge.
    static func snippet(of line: String, limit: Int = 70) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}
