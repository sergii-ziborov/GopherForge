import Foundation

/// The bounds every guest program runs under.
///
/// These are product limits, not suggestions: the sandbox gate test asserts a
/// program that asks for more is stopped rather than allowed to grow.
enum WasmSandboxPolicy {
    static let writableGuestDirectory = "/sandbox"
    static let userProgramMemoryLimitBytes = 64 * 1024 * 1024

    /// Measured rather than guessed. A Go hello-world links a function table of
    /// 5,740 entries and a table-driven test binary 6,966 — most of it the Go
    /// runtime, before the user has written anything. The old 4,096 predated
    /// any real Go program and stopped every one of them at instantiation. The
    /// ceiling is still a ceiling; a table this size costs well under a
    /// megabyte, and the limit that actually bounds a runaway program is the
    /// memory one above.
    static let userProgramTableElementLimit = 32_768

    /// The toolchain itself needs far more headroom than a user program: a Go
    /// build holds the package graph and export data in memory.
    static let toolchainMemoryLimitBytes = 1_024 * 1024 * 1024

    /// `cmd/compile` declares just over 20,000 function-table entries. Handing
    /// the toolchain a limit below that denies the table at instantiation, and
    /// the guest then exits without writing a word — a build that fails for a
    /// reason nothing on screen could explain. The headroom is for the Go
    /// release after this one; the ceiling still exists, it is simply the
    /// right one.
    static let toolchainTableElementLimit = 65_536

    static var memoryLimitLabel: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(userProgramMemoryLimitBytes),
            countStyle: .memory
        )
    }
}
