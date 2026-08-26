import Foundation

/// Builds the argv and environment for one toolchain phase.
///
/// Every phase runs the same bundled driver; only the sub-command differs, so
/// the mapping lives in one place and stays easy to audit against what the app
/// claims it runs.
enum GoToolInvocation {
    /// Guest paths inside the job sandbox. They are fixed so that diagnostics
    /// always come back with the same prefix and can be normalised.
    enum GuestPath {
        static let work = "/work"
        static let goroot = "/goroot"
        static let cache = "/cache"
        static let temp = "/tmp"
    }

    static func arguments(for phase: CompilationResult.Phase, packagePattern: String = "./...") -> [String] {
        switch phase {
        case .format:
            ["go", "fmt", packagePattern]
        case .vet:
            ["go", "vet", packagePattern]
        case .build:
            // -o discards the binary: the build phase only has to prove the
            // package graph type-checks and links.
            ["go", "build", "-o", "/dev/null", packagePattern]
        case .run:
            ["go", "build", "-o", "\(GuestPath.work)/program.wasm", "."]
        case .test:
            ["go", "test", packagePattern]
        case .setup:
            ["go", "version"]
        }
    }

    /// The guest environment.
    ///
    /// `GOOS=wasip1` matters: the app runs guest programs under WASI in the
    /// same interpreter it uses for the toolchain, so user programs are built
    /// for the platform they will actually execute on. `GOFLAGS=-mod=mod`
    /// keeps builds working from the bundled module cache without a network.
    static func environment(goVersion: String) -> [String: String] {
        [
            "GOROOT": GuestPath.goroot,
            "GOCACHE": GuestPath.cache,
            "GOMODCACHE": "\(GuestPath.cache)/mod",
            "GOTMPDIR": GuestPath.temp,
            "GOOS": "wasip1",
            "GOARCH": "wasm",
            "GOFLAGS": "-mod=mod",
            // No network is reachable from the sandbox; make that explicit so
            // the toolchain fails fast with a clear message instead of hanging
            // on a proxy dial that can never succeed.
            "GOPROXY": "off",
            "GOTOOLCHAIN": "local",
            "GOVERSION": goVersion,
            "HOME": GuestPath.work,
        ]
    }

    static func programArguments(programName: String = "program") -> [String] {
        [programName]
    }
}
