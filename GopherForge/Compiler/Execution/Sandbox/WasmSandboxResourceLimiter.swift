import Foundation
@_spi(Fuzzing) import WasmKit

/// Enforces the sandbox bounds and remembers which one was hit.
///
/// WasmKit reports a denied growth as a trap, which is indistinguishable from
/// any other trap at the call site, so the reason is recorded here and read
/// back after the failure to produce an honest message.
final class WasmSandboxResourceLimiter: ResourceLimiter, @unchecked Sendable {
    enum DeniedResource: String, Equatable {
        case memory
        case table
    }

    private let memoryLimitBytes: Int
    private let tableElementLimit: Int
    private let lock = NSLock()
    private var storedDeniedResource: DeniedResource?

    init(
        memoryLimitBytes: Int = WasmSandboxPolicy.userProgramMemoryLimitBytes,
        tableElementLimit: Int = WasmSandboxPolicy.userProgramTableElementLimit
    ) {
        self.memoryLimitBytes = memoryLimitBytes
        self.tableElementLimit = tableElementLimit
    }

    var deniedResource: DeniedResource? {
        lock.withLock { storedDeniedResource }
    }

    func limitMemoryGrowth(to desired: Int) throws -> Bool {
        let allowed = desired <= memoryLimitBytes
        if !allowed {
            lock.withLock { storedDeniedResource = .memory }
        }
        return allowed
    }

    func limitTableGrowth(to desired: Int) throws -> Bool {
        let allowed = desired <= tableElementLimit
        if !allowed {
            lock.withLock { storedDeniedResource = .table }
        }
        return allowed
    }
}
