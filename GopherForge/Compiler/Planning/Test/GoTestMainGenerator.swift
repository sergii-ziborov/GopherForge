import Foundation

/// Writes the `_testmain.go` that turns a package into a test binary.
///
/// `go test` generates this file too, for the same reason: the `testing`
/// package needs a table of entry points, and Go has no runtime discovery to
/// build one. The shape here follows upstream's, including the way a custom
/// `TestMain` takes over, so a test that passes on a laptop behaves the same
/// way in the app.
enum GoTestMainGenerator {
    static let internalAlias = "_test"
    static let externalAlias = "_xtest"

    static func source(importPath: String, functions: [GoTestFunction], hasExternalPackage: Bool) -> String {
        let entries = functions.filter { !$0.isCustomMain }
        let customMain = functions.first(where: \.isCustomMain)
        let needsInternal = functions.contains { !$0.isExternal }
        let needsExternal = hasExternalPackage && functions.contains(where: \.isExternal)

        var lines = ["package main", ""]
        lines.append(contentsOf: imports(
            importPath: importPath,
            needsInternal: needsInternal,
            needsExternal: needsExternal,
            needsReflect: customMain != nil
        ))
        lines.append("")
        lines.append(contentsOf: tables(entries))
        lines.append("")
        lines.append(contentsOf: main(importPath: importPath, customMain: customMain))
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Pieces

    private static func imports(
        importPath: String,
        needsInternal: Bool,
        needsExternal: Bool,
        needsReflect: Bool
    ) -> [String] {
        var lines = ["import ("]
        lines.append("\t\"os\"")
        if needsReflect { lines.append("\t\"reflect\"") }
        lines.append("\t\"testing\"")
        lines.append("\t\"testing/internal/testdeps\"")
        if needsInternal || needsExternal { lines.append("") }
        if needsInternal { lines.append("\t\(internalAlias) \"\(importPath)\"") }
        if needsExternal { lines.append("\t\(externalAlias) \"\(importPath)_test\"") }
        lines.append(")")
        return lines
    }

    private static func tables(_ functions: [GoTestFunction]) -> [String] {
        [
            table(
                name: "tests",
                type: "testing.InternalTest",
                rows: functions.filter { $0.kind == .test }.map(nameAndFunction)
            ),
            table(
                name: "benchmarks",
                type: "testing.InternalBenchmark",
                rows: functions.filter { $0.kind == .benchmark }.map(nameAndFunction)
            ),
            table(
                name: "fuzzTargets",
                type: "testing.InternalFuzzTarget",
                rows: functions.filter { $0.kind == .fuzz }.map(nameAndFunction)
            ),
            table(
                name: "examples",
                type: "testing.InternalExample",
                rows: functions.filter { $0.kind == .example }.map { function in
                    "\(nameAndFunction(function)), Output: \(quoted(function.expectedOutput))"
                }
            ),
        ].flatMap { $0 }
    }

    private static func table(name: String, type: String, rows: [String]) -> [String] {
        guard !rows.isEmpty else { return ["var \(name) = []\(type){}"] }
        return ["var \(name) = []\(type){"]
            + rows.map { "\t{\($0)}," }
            + ["}"]
    }

    private static func nameAndFunction(_ function: GoTestFunction) -> String {
        let alias = function.isExternal ? externalAlias : internalAlias
        return "Name: \(quoted(function.name)), F: \(alias).\(function.name)"
    }

    private static func main(importPath: String, customMain: GoTestFunction?) -> [String] {
        var lines = ["func main() {"]
        lines.append("\ttestdeps.ImportPath = \(quoted(importPath))")
        lines.append("\tm := testing.MainStart(testdeps.TestDeps{}, tests, benchmarks, fuzzTargets, examples)")

        if let customMain {
            let alias = customMain.isExternal ? externalAlias : internalAlias
            // Upstream reads the exit code back off the unexported field for
            // exactly this case: TestMain may return without calling os.Exit,
            // and the binary still has to report what the run decided.
            lines.append("\t\(alias).TestMain(m)")
            lines.append("\tos.Exit(int(reflect.ValueOf(m).Elem().FieldByName(\"exitCode\").Int()))")
        } else {
            lines.append("\tos.Exit(m.Run())")
        }

        lines.append("}")
        return lines
    }

    /// A Go interpreted string literal. Only the escapes a test name or an
    /// example's output can actually contain are handled, and anything else
    /// non-printable is written as an escape rather than embedded raw.
    private static func quoted(_ value: String) -> String {
        var result = "\""
        for character in value.unicodeScalars {
            switch character {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default:
                if character.value < 0x20 {
                    result += String(format: "\\x%02x", character.value)
                } else {
                    result.unicodeScalars.append(character)
                }
            }
        }
        return result + "\""
    }
}
