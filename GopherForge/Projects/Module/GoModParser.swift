import Foundation

/// Reads `go.mod`.
///
/// The format has two shapes for every directive — a single line and a
/// parenthesised block — and the parser handles both rather than assuming
/// whichever one `go mod init` happened to write.
enum GoModParser {
    static func parse(_ source: String) -> GoModule? {
        var modulePath: String?
        var goVersion: String?
        var toolchain: String?
        var requirements: [GoModule.Requirement] = []
        var replacements: [GoModule.Replacement] = []
        var openBlock: Directive?

        for rawLine in source.split(whereSeparator: \.isNewline) {
            // Structure is decided on the comment-free text, but entries are
            // handed the original: `// indirect` is a marker, not a comment,
            // and stripping it here would erase it before it is read.
            let uncommented = stripComment(from: String(rawLine))
            let trimmed = uncommented.trimmingCharacters(in: .whitespaces)
            let entry = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let block = openBlock {
                if trimmed == ")" {
                    openBlock = nil
                    continue
                }
                append(entry, to: block, requirements: &requirements, replacements: &replacements)
                continue
            }

            let fields = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let directive = fields.first.flatMap(Directive.init(rawValue:)) else { continue }

            if fields.count >= 2, fields[1] == "(" {
                openBlock = directive
                continue
            }

            switch directive {
            case .module where fields.count >= 2:
                modulePath = unquote(fields[1])
            case .go where fields.count >= 2:
                goVersion = fields[1]
            case .toolchain where fields.count >= 2:
                toolchain = fields[1]
            case .require, .replace:
                append(
                    entry.split(separator: " ", maxSplits: 1).dropFirst().joined(),
                    to: directive,
                    requirements: &requirements,
                    replacements: &replacements
                )
            default:
                continue
            }
        }

        guard let modulePath, !modulePath.isEmpty else { return nil }
        return GoModule(
            modulePath: modulePath,
            goVersion: goVersion,
            toolchain: toolchain,
            requirements: requirements.sorted {
                $0.path.localizedStandardCompare($1.path) == .orderedAscending
            },
            replacements: replacements.sorted {
                $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }
        )
    }

    // MARK: - Directives

    private enum Directive: String {
        case module
        case go
        case toolchain
        case require
        case replace
        case exclude
        case retract
    }

    private static func append(
        _ entry: String,
        to directive: Directive,
        requirements: inout [GoModule.Requirement],
        replacements: inout [GoModule.Replacement]
    ) {
        switch directive {
        case .require:
            if let requirement = requirement(from: entry) { requirements.append(requirement) }
        case .replace:
            if let replacement = replacement(from: entry) { replacements.append(replacement) }
        default:
            break
        }
    }

    /// `github.com/pkg/errors v0.9.1 // indirect`
    private static func requirement(from entry: String) -> GoModule.Requirement? {
        let isIndirect = entry.contains("// indirect")
        let fields = stripComment(from: entry)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard fields.count >= 2 else { return nil }
        return GoModule.Requirement(
            path: unquote(fields[0]),
            version: fields[1],
            isIndirect: isIndirect
        )
    }

    /// `example.com/old => ./local` or `example.com/old v1.0.0 => example.com/new v1.2.0`
    private static func replacement(from entry: String) -> GoModule.Replacement? {
        let sides = entry.components(separatedBy: "=>")
        guard sides.count == 2 else { return nil }
        let left = sides[0].trimmingCharacters(in: .whitespaces)
        let right = sides[1].trimmingCharacters(in: .whitespaces)
        guard let path = left.split(separator: " ").first.map(String.init), !right.isEmpty else {
            return nil
        }
        return GoModule.Replacement(path: unquote(path), replacement: right)
    }

    // MARK: - Line reading

    /// `//` starts a comment unless it is inside a quoted string, which module
    /// paths never are in practice but versions with metadata can be.
    private static func stripComment(from line: String) -> String {
        var isQuoted = false
        var previous: Character?
        for index in line.indices {
            let character = line[index]
            if character == "\"" { isQuoted.toggle() }
            if character == "/", previous == "/", !isQuoted {
                return String(line[..<line.index(before: index)])
            }
            previous = character
        }
        return line
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
    }
}
