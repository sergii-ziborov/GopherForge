import Foundation

/// A test entry point found in a `_test.go` file.
struct GoTestFunction: Equatable {
    enum Kind: String, Equatable {
        case test
        case benchmark
        case example
        case fuzz
    }

    let kind: Kind
    let name: String
    /// True when the function lives in a `package foo_test` file, which the
    /// generated main has to reach through a different import.
    let isExternal: Bool
    /// The text of an example's `// Output:` comment. Empty means the example
    /// is compiled but not run, which is what `go test` does.
    let expectedOutput: String

    /// `TestMain` is not a test; it replaces the generated entry point.
    var isCustomMain: Bool { kind == .test && name == "TestMain" }
}

/// Finds the functions `go test` would turn into a test binary.
///
/// `cmd/go` does this with the real parser; here a line scanner is enough,
/// because a test entry point is by definition a top-level declaration written
/// at column zero with a fixed shape.
enum GoTestFunctionScanner {
    nonisolated(unsafe) private static let declaration =
        /^func\s+(?<kind>Test|Benchmark|Example|Fuzz)(?<suffix>[A-Z_][_\p{L}\p{Nd}]*)?\s*\(/

    static func scan(source: String, isExternal: Bool) -> [GoTestFunction] {
        let lines = source.components(separatedBy: "\n")
        var found: [GoTestFunction] = []

        for (index, line) in lines.enumerated() {
            guard let match = line.firstMatch(of: declaration) else { continue }
            let kindText = String(match.output.kind)
            let name = kindText + (match.output.suffix.map(String.init) ?? "")
            guard let kind = GoTestFunction.Kind(rawValue: kindText.lowercased()) else { continue }

            // Only examples carry an expected output, and only from the
            // comment block that closes their body.
            let output = kind == .example ? exampleOutput(in: lines, startingAt: index) : ""
            found.append(
                GoTestFunction(kind: kind, name: name, isExternal: isExternal, expectedOutput: output)
            )
        }

        return found
    }

    /// Reads the `// Output:` block that ends an example's body.
    ///
    /// The convention is exact: the comment is the last thing in the function,
    /// so the scan runs from the declaration to the closing brace at column
    /// zero and keeps the last such block it saw.
    private static func exampleOutput(in lines: [String], startingAt index: Int) -> String {
        var collected: [String] = []
        var collecting = false

        for line in lines[(index + 1)...] {
            if line.hasPrefix("}") { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !collecting {
                let lowered = trimmed.lowercased()
                if lowered.hasPrefix("// output:") || lowered.hasPrefix("//output:") {
                    collecting = true
                    let remainder = trimmed
                        .drop(while: { $0 == "/" })
                        .drop(while: { $0 == " " })
                        .dropFirst("output:".count)
                    let firstLine = remainder.trimmingCharacters(in: .whitespaces)
                    if !firstLine.isEmpty { collected.append(firstLine) }
                }
                continue
            }

            guard trimmed.hasPrefix("//") else { break }
            collected.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }

        return collected.isEmpty ? "" : collected.joined(separator: "\n") + "\n"
    }
}
