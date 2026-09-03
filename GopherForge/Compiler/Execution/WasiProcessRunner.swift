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
        /// How much of each stream is kept before the rest is counted and
        /// dropped. Defaults to the toolchain's ceiling because most callers
        /// here are the toolchain; running a user's program passes its own.
        let outputLimitBytes: Int

        init(
            arguments: [String],
            environment: [String: String] = [:],
            preopens: [String: String],
            memoryLimitBytes: Int = WasmSandboxPolicy.toolchainMemoryLimitBytes,
            tableElementLimit: Int = WasmSandboxPolicy.userProgramTableElementLimit,
            outputLimitBytes: Int = WasmSandboxPolicy.toolchainOutputLimitBytes
        ) {
            self.arguments = arguments
            self.environment = environment
            self.preopens = preopens
            self.memoryLimitBytes = memoryLimitBytes
            self.tableElementLimit = tableElementLimit
            self.outputLimitBytes = outputLimitBytes
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

    init(engineProvider: WasmEngineProvider = .shared) {
        self.engineProvider = engineProvider
    }

    func run(module: Module, invocation: Invocation) throws -> (exitCode: UInt32, output: Output) {
        let capture = try StreamCapture(limitBytes: invocation.outputLimitBytes)
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

/// Captures a guest's stdout and stderr, keeping a bounded amount of each.
///
/// This wrote to files once, because a Go build emits more than a pipe buffer
/// holds and a blocked writer inside the interpreter would deadlock the job.
/// The problem with a file is that nothing bounds it: the memory limiter never
/// fires on output, because the bytes leave the sandbox as they are produced,
/// and `for { fmt.Println("x") }` filled the device and then produced a string
/// too large to render.
///
/// So: a pipe per stream, drained continuously by a thread of its own. Draining
/// is what keeps the old deadlock away — the reader never stops reading, even
/// after the limit, it simply stops keeping. The guest is never blocked by us,
/// and the host never holds more than the limit.
private final class StreamCapture {
    private let stdout: BoundedStream
    private let stderr: BoundedStream

    var stdoutDescriptor: Int32 { stdout.writingDescriptor }
    var stderrDescriptor: Int32 { stderr.writingDescriptor }

    init(limitBytes: Int) throws {
        stdout = BoundedStream(limitBytes: limitBytes)
        stderr = BoundedStream(limitBytes: limitBytes)
    }

    func finish() throws -> WasiProcessRunner.Output {
        WasiProcessRunner.Output(stdout: stdout.take(), stderr: stderr.take())
    }
}

/// One pipe, drained by one thread, keeping at most `limitBytes`.
///
/// Not private so the limit can be tested directly. Proving it through a real
/// guest would mean compiling and running a Go program that never stops, which
/// is not something a unit test should need to do.
final class BoundedStream {
    private let pipe = Pipe()
    private let limitBytes: Int
    private let lock = NSLock()
    private var kept = Data()
    private var discarded = 0
    private var finished = false
    private let drained = DispatchSemaphore(value: 0)

    var writingDescriptor: Int32 { pipe.fileHandleForWriting.fileDescriptor }

    init(limitBytes: Int) {
        self.limitBytes = limitBytes

        // A thread rather than a DispatchQueue: this blocks in `read` for as
        // long as the guest runs, and parking a cooperative pool thread for
        // that long is how a concurrency runtime starves.
        let thread = Thread { [pipe, limitBytes, lock, drained] in
            let reading = pipe.fileHandleForReading
            while true {
                let chunk = reading.availableData
                if chunk.isEmpty { break }
                lock.lock()
                let room = limitBytes - self.kept.count
                if room > 0 {
                    self.kept.append(chunk.prefix(room))
                }
                if chunk.count > max(room, 0) {
                    self.discarded += chunk.count - max(room, 0)
                }
                lock.unlock()
            }
            drained.signal()
        }
        thread.name = "gopherforge.stream-capture"
        thread.start()
    }

    /// Closes the write end, waits for the reader to see the end of the stream,
    /// and returns what was kept.
    func take() -> String {
        lock.lock()
        let alreadyFinished = finished
        finished = true
        lock.unlock()
        guard !alreadyFinished else { return "" }

        try? pipe.fileHandleForWriting.close()
        drained.wait()
        try? pipe.fileHandleForReading.close()

        lock.lock()
        defer { lock.unlock() }
        var text = String(decoding: kept, as: UTF8.self)
        if discarded > 0 {
            // Said plainly and in the output itself. A silently truncated
            // stream reads as a program that stopped printing.
            let limit = ByteCountFormatter.string(fromByteCount: Int64(limitBytes), countStyle: .file)
            text += "\n… output stopped being kept after \(limit); "
            text += "\(discarded) more bytes were produced and discarded.\n"
        }
        return text
    }
}
