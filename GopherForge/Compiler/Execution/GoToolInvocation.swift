import Foundation

/// The environment every toolchain step runs under.
///
/// The argv of a step is the build planner's business — it differs per package
/// and per phase — but the environment is the same for all of them, so it lives
/// here where it can be read in one go and audited against what the app claims.
enum GoToolInvocation {
    /// The guest environment.
    ///
    /// `GOOS=wasip1` matters: the app runs guest programs under WASI in the
    /// same interpreter it uses for the toolchain, so user programs are built
    /// for the platform they will actually execute on.
    static func environment(goVersion: String) -> [String: String] {
        [
            "GOROOT": GoGuestPath.goroot,
            "GOCACHE": GoGuestPath.cache,
            "GOMODCACHE": "\(GoGuestPath.cache)/mod",
            "GOTMPDIR": GoGuestPath.temp,
            "GOOS": "wasip1",
            "GOARCH": "wasm",
            // No network is reachable from the sandbox; make that explicit so
            // anything that would reach for one fails fast with a clear message
            // instead of hanging on a dial that can never succeed.
            "GOPROXY": "off",
            "GOTOOLCHAIN": "local",
            "GOVERSION": goVersion,
            "HOME": GoGuestPath.work,
        ]
    }

    static func programArguments(programName: String = "program") -> [String] {
        [programName]
    }
}
