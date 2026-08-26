import Foundation
import SystemPackage
@_spi(Fuzzing) import WasmKit
import WasmKitWASI

/// Runs one WASI module to completion and returns what it wrote.
///
/// Both the Go toolchain and the user's compiled program are ordinary WASI
/// programs, so they share this runner. The only differences are the argv, the
/// preopened directories and the resource limits, all of which are inputs.
struct WasiProcessRunner: Sendable {
    struct Output: Sendable {
        let stdout: String
        let stderr: String
    }

    struct Invocation: Sendable {
        let arguments: [String]
        let environment: [String: String]
        let preopens: [String: String]
        let memoryLimitBytes: Int
        let tableElementLimit: Int

        init(
            arguments: [String],
            environment: [String: String] = [:],
            preopens: [String: String],
            memoryLimitBytes: Int = WasmSandboxPolicy.toolchainMemoryLimitBytes,
            tableElementLimit: Int = WasmSandboxPolicy.userProgramTableElementLimit
        ) {
            self.arguments = arguments
            self.environment = environment
            self.preopens = preopens
            self.memoryLimitBytes = memoryLimitBytes
            self.tableElementLimit = tableElementLimit
        }
    }

    enum RunFailure: Error {
        /// The guest asked for more than the sandbox allows. Carried
        /// separately from a generic trap so the UI can explain the limit
        /// instead of showing an interpreter error.
        case limitExceeded(WasmSandboxResourceLimiter.DeniedResource, Output)
        case trapped(any Error, Output)
    }

    private let engineProvider: WasmEngineProvider
    private let captureDirectory: URL
    private let capturePrefix: String

    init(
        captureDirectory: URL,
        capturePrefix: String,
        engineProvider: WasmEngineProvider = .shared
    ) {
        self.captureDirectory = captureDirectory
        self.capturePrefix = capturePrefix
        self.engineProvider = engineProvider
    }

    func run(module: Module, invocation: Invocation) throws -> (exitCode: UInt32, output: Output) {
        let capture = try StreamCapture(directory: captureDirectory, prefix: capturePrefix)
        let limiter = WasmSandboxResourceLimiter(
            memoryLimitBytes: invocation.memoryLimitBytes,
            tableElementLimit: invocation.tableElementLimit
        )

        do {
            let exitCode = try invoke(module: module, invocation: invocation, capture: capture, limiter: limiter)
            return (exitCode, try capture.finish())
        } catch {
            let output = (try? capture.finish()) ?? Output(stdout: "", stderr: "")
            if let denied = limiter.deniedResource {
                throw RunFailure.limitExceeded(denied, output)
            }
            throw RunFailure.trapped(error, output)
        }
    }

    private func invoke(
        module: Module,
        invocation: Invocation,
        capture: StreamCapture,
        limiter: WasmSandboxResourceLimiter
    ) throws -> UInt32 {
        let preopens = invocation.preopens.map {
            WASIBridgeToHost.Preopen(guestPath: $0.key, hostPath: $0.value)
        }
        let wasi = try WASIBridgeToHost(
            args: invocation.arguments,
            environment: invocation.environment,
            preopens: preopens,
            stdout: FileDescriptor(rawValue: capture.stdoutDescriptor),
            stderr: FileDescriptor(rawValue: capture.stderrDescriptor)
        )
        return try wasi.runAndClose { wasi in
            let store = Store(engine: engineProvider.engine())
            store.resourceLimiter = limiter
            var imports = Imports()
            wasi.link(to: &imports, store: store)
            let instance = try module.instantiate(store: store, imports: imports)
            return try wasi.start(instance)
        }
    }
}

/// Captures a guest's stdout and stderr into files.
///
/// Files rather than pipes: a Go build can emit more output than a pipe buffer
/// holds, and a blocked writer inside the interpreter would deadlock the job.
private final class StreamCapture {
    private let stdoutURL: URL
    private let stderrURL: URL
    private let stdoutHandle: FileHandle
    private let stderrHandle: FileHandle
    private var isClosed = false

    var stdoutDescriptor: Int32 { stdoutHandle.fileDescriptor }
    var stderrDescriptor: Int32 { stderrHandle.fileDescriptor }

    init(directory: URL, prefix: String) throws {
        stdoutURL = directory.appendingPathComponent("\(prefix)-stdout.log")
        stderrURL = directory.appendingPathComponent("\(prefix)-stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        stderrHandle = try FileHandle(forWritingTo: stderrURL)
    }

    func finish() throws -> WasiProcessRunner.Output {
        if !isClosed {
            try stdoutHandle.close()
            try stderrHandle.close()
            isClosed = true
        }
        return WasiProcessRunner.Output(
            stdout: String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self),
            stderr: String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self)
        )
    }
}
