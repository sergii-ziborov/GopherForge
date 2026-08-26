import Foundation

/// The bounds every guest program runs under.
///
/// These are product limits, not suggestions: the sandbox gate test asserts a
/// program that asks for more is stopped rather than allowed to grow.
enum WasmSandboxPolicy {
    static let writableGuestDirectory = "/sandbox"
    static let userProgramMemoryLimitBytes = 64 * 1024 * 1024
    static let userProgramTableElementLimit = 4_096

    /// The toolchain itself needs far more headroom than a user program: a Go
    /// build holds the package graph and export data in memory.
    static let toolchainMemoryLimitBytes = 1_024 * 1024 * 1024

    static var memoryLimitLabel: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(userProgramMemoryLimitBytes),
            countStyle: .memory
        )
    }
}
