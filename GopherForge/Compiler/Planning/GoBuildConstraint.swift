import Foundation

/// Decides whether a file is part of the build.
///
/// Go excludes a file in two ways and both have to be honoured, or a package
/// with two mutually exclusive implementations compiles both and every symbol
/// in it is declared twice. That is not a corner case: `go-cmp` ships
/// `debug_enable.go` and `debug_disable.go`, and so does half the standard
/// library.
///
/// The two ways are the file's name — `foo_linux.go`, `foo_amd64.go`,
/// `foo_linux_amd64.go` — and a `//go:build` line in its header. The older
/// `// +build` form is still read, because modules published before Go 1.17
/// are still on the proxy.
struct GoBuildConstraint {
    /// What is true for this build. Fixed by the product: the app compiles for
    /// `wasip1/wasm` with the bundled `gc`, and there is no cgo.
    struct Environment: Sendable {
        let goos: String
        let goarch: String
        /// `go1.21`, `go1.22`… every release up to the bundled one, which is
        /// how a `//go:build go1.22` line is satisfied.
        let releaseTags: Set<String>
        let extra: Set<String>

        static func wasip1(goVersion: String) -> Environment {
            Environment(
                goos: "wasip1",
                goarch: "wasm",
                releaseTags: Self.releaseTags(upTo: goVersion),
                extra: ["gc", "wasip1", "wasm"]
            )
        }

        /// Go defines every `go1.N` up to the current release as satisfied, so
        /// a file guarded by an older one still builds.
        static func releaseTags(upTo goVersion: String) -> Set<String> {
            let digits = goVersion.drop(while: { !$0.isNumber }).split(separator: ".")
            guard digits.count >= 2, let minor = Int(digits[1]) else { return ["go1.1"] }
            return Set((1...max(1, minor)).map { "go1.\($0)" })
        }

        func satisfies(_ tag: String) -> Bool {
            tag == goos || tag == goarch || releaseTags.contains(tag) || extra.contains(tag)
        }
    }

    let environment: Environment

    /// True when this file belongs in the build.
    func includes(path: String, source: String) -> Bool {
        guard matchesFileName(path) else { return false }
        guard let expression = Self.expression(in: source) else { return true }
        return evaluate(expression)
    }

    // MARK: - File names

    /// `name_GOOS.go`, `name_GOARCH.go` and `name_GOOS_GOARCH.go` exclude a
    /// file whose suffix names a different platform. A suffix that is not a
    /// known GOOS or GOARCH is just part of the name.
    func matchesFileName(_ path: String) -> Bool {
        var name = path.split(separator: "/").last.map(String.init) ?? path
        guard name.hasSuffix(".go") else { return true }
        name = String(name.dropLast(3))
        if name.hasSuffix("_test") { name = String(name.dropLast(5)) }

        let parts = name.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return true }

        let last = parts[parts.count - 1]
        let secondLast = parts.count >= 3 ? parts[parts.count - 2] : ""

        if Self.knownArchitectures.contains(last) {
            guard last == environment.goarch else { return false }
            if Self.knownOperatingSystems.contains(secondLast) {
                return secondLast == environment.goos
            }
            return true
        }
        if Self.knownOperatingSystems.contains(last) {
            return last == environment.goos
        }
        return true
    }

    // MARK: - Build lines

    /// The `//go:build` expression, or the `// +build` lines converted to one.
    /// Only the header is read: both forms must appear before the package
    /// clause, so nothing after it can change the answer.
    static func expression(in source: String) -> String? {
        var legacy: [String] = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("package ") { break }
            if line.hasPrefix("//go:build ") {
                // The modern form wins outright when both are present.
                return String(line.dropFirst("//go:build ".count))
            }
            if line.hasPrefix("// +build ") {
                legacy.append(String(line.dropFirst("// +build ".count)))
            }
        }
        guard !legacy.isEmpty else { return nil }
        return convertLegacy(legacy)
    }

    /// `// +build` lines are ANDed; within a line, space is OR and comma is
    /// AND. Rewritten into the modern syntax so there is one evaluator.
    static func convertLegacy(_ lines: [String]) -> String {
        let clauses = lines.map { line -> String in
            let alternatives = line.split(separator: " ").map { group -> String in
                let terms = group.split(separator: ",").map(String.init)
                return terms.count == 1 ? terms[0] : "(" + terms.joined(separator: " && ") + ")"
            }
            return alternatives.count == 1
                ? alternatives[0]
                : "(" + alternatives.joined(separator: " || ") + ")"
        }
        return clauses.count == 1 ? clauses[0] : clauses.joined(separator: " && ")
    }

    func evaluate(_ expression: String) -> Bool {
        var tokens = Self.tokenize(expression)[...]
        let value = parseOr(&tokens)
        // Anything left over means the expression was malformed; Go would
        // refuse the file, and so does this.
        return tokens.isEmpty ? value : false
    }

    // MARK: - Expression parsing

    private func parseOr(_ tokens: inout ArraySlice<String>) -> Bool {
        var value = parseAnd(&tokens)
        while tokens.first == "||" {
            tokens = tokens.dropFirst()
            // No short-circuit: the right side still has to be consumed.
            value = parseAnd(&tokens) || value
        }
        return value
    }

    private func parseAnd(_ tokens: inout ArraySlice<String>) -> Bool {
        var value = parseUnary(&tokens)
        while tokens.first == "&&" {
            tokens = tokens.dropFirst()
            value = parseUnary(&tokens) && value
        }
        return value
    }

    private func parseUnary(_ tokens: inout ArraySlice<String>) -> Bool {
        guard let token = tokens.first else { return false }
        tokens = tokens.dropFirst()

        switch token {
        case "!": return !parseUnary(&tokens)
        case "(":
            let value = parseOr(&tokens)
            if tokens.first == ")" { tokens = tokens.dropFirst() }
            return value
        default: return environment.satisfies(token)
        }
    }

    static func tokenize(_ expression: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var index = expression.startIndex

        func flush() {
            if !current.isEmpty { tokens.append(current); current = "" }
        }

        while index < expression.endIndex {
            let character = expression[index]
            let next = expression.index(after: index)
            switch character {
            case " ", "\t":
                flush()
            case "(", ")", "!":
                flush()
                tokens.append(String(character))
            case "&", "|":
                flush()
                if next < expression.endIndex, expression[next] == character {
                    tokens.append(String(repeating: String(character), count: 2))
                    index = next
                }
            default:
                current.append(character)
            }
            index = expression.index(after: index)
        }
        flush()
        return tokens
    }

    static let knownOperatingSystems: Set<String> = [
        "aix", "android", "darwin", "dragonfly", "freebsd", "hurd", "illumos",
        "ios", "js", "linux", "nacl", "netbsd", "openbsd", "plan9", "solaris",
        "wasip1", "windows", "zos",
    ]

    static let knownArchitectures: Set<String> = [
        "386", "amd64", "amd64p32", "arm", "arm64", "arm64be", "armbe",
        "loong64", "mips", "mips64", "mips64le", "mips64p32", "mips64p32le",
        "mipsle", "ppc", "ppc64", "ppc64le", "riscv", "riscv64", "s390",
        "s390x", "sparc", "sparc64", "wasm",
    ]
}
