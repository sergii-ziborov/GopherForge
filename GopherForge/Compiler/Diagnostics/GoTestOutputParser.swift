import Foundation

/// Parses the human-readable `go test` stream.
///
/// The app reads the same output a developer would read in a terminal rather
/// than requiring `-json`, which is not guaranteed to be available in every
/// bundled-toolchain configuration.
enum GoTestOutputParser {
    // See GoDiagnosticParser: immutable compiled literals, kept concrete so
    // the named captures survive.
    nonisolated(unsafe) private static let casePattern =
        /^\s*---\s+(?<outcome>PASS|FAIL|SKIP):\s+(?<name>\S+)\s+\((?<elapsed>[\d.]+)s\)/
    nonisolated(unsafe) private static let packagePattern = /^(?<status>ok|FAIL|\?)\s+(?<package>\S+)/

    static func parse(stdout: String) -> [GoTestResult] {
        var results: [GoTestResult] = []
        var currentPackage = ""
        var pendingOutput: [String] = []

        for rawLine in stdout.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if let packageMatch = line.firstMatch(of: packagePattern) {
                currentPackage = String(packageMatch.output.package)
                continue
            }

            if let match = line.firstMatch(of: casePattern) {
                results.append(
                    GoTestResult(
                        name: String(match.output.name),
                        packagePath: currentPackage,
                        outcome: outcome(String(match.output.outcome)),
                        elapsedSeconds: Double(match.output.elapsed),
                        output: pendingOutput.joined(separator: "\n")
                    )
                )
                pendingOutput.removeAll(keepingCapacity: true)
                continue
            }

            if line.hasPrefix("    ") || line.hasPrefix("\t") {
                pendingOutput.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        return results
    }

    private static func outcome(_ raw: String) -> GoTestResult.Outcome {
        switch raw {
        case "PASS": .passed
        case "SKIP": .skipped
        default: .failed
        }
    }
}
