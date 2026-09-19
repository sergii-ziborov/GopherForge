import Foundation
import WasmKit

/// Owns the single WasmKit engine the app reuses across jobs.
///
/// Engine construction is not free and the configuration is a deliberate
/// choice rather than a default, so it lives in one place instead of being
/// repeated at every call site.
final class WasmEngineProvider: @unchecked Sendable {
    static let shared = WasmEngineProvider()

    private let lock = NSLock()
    private var cachedEngine: Engine?

    func engine() -> Engine {
        lock.withLock {
            if let cachedEngine { return cachedEngine }
            let engine = Engine(configuration: Self.configuration)
            cachedEngine = engine
            return engine
        }
    }

    private static var configuration: EngineConfiguration {
        EngineConfiguration(
            // WasmKit 0.3.1's direct-threaded interpreter crashes in optimized
            // iOS Simulator builds while executing large toolchain modules.
            // Token threading is the supported fallback and stays stable in
            // both Debug and Release configurations.
            threadingModel: .token,
            compilationMode: .lazy,
            stackSize: 16 * 1024 * 1024,
            memoryBoundsChecking: .software
        )
    }
}
