import Foundation

struct GoDebugPoint: Codable, Equatable, Sendable {
    let id: Int
    let file: String
    let line: Int
    let function: String
    let kind: Int
}

struct GoDebugFrame: Equatable, Sendable, Identifiable {
    let id: Int
    let function: String
    let file: String
    var line: Int
}

struct GoDebugPause: Sendable {
    let point: GoDebugPoint
    let goroutine: UInt32
    let frames: [GoDebugFrame]
    let locals: [String: String]
}

/// One execution's stop state. The guest waits on its compiler worker; UI and
/// storage stay responsive. The host sees bounded JSON, never guest pointers.
final class GoDebugControl: @unchecked Sendable, Equatable {
    enum Step { case into, over, out }
    struct Stopped: Error, LocalizedError { var errorDescription: String? { "Debug session stopped." } }
    static func == (lhs: GoDebugControl, rhs: GoDebugControl) -> Bool { lhs === rhs }

    private let condition = NSCondition()
    private let points: [Int: GoDebugPoint]
    private let breakpoints: Set<Int>
    private let onPause: @Sendable (GoDebugPause) -> Void
    private var stacks: [UInt32: [GoDebugFrame]] = [:]
    private var cancelled = false
    private var paused = false
    private var stepping: Step?
    private var baselineDepth = 0
    private var baselineGoroutine: UInt32 = 0

    init(points: [GoDebugPoint], breakpoints: Set<Int>, onPause: @escaping @Sendable (GoDebugPause) -> Void) {
        self.points = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        self.breakpoints = breakpoints
        self.onPause = onPause
    }

    func checkpoint(kind: UInt32, id: Int, goroutine: UInt32, payload: Data) throws {
        condition.lock()
        if cancelled { condition.unlock(); throw Stopped() }
        guard let point = points[id], payload.count <= 65_536 else { condition.unlock(); throw Stopped() }
        var stack = stacks[goroutine] ?? []
        if kind == 1 {
            guard stack.count < 256 else { condition.unlock(); throw Stopped() }
            stack.append(GoDebugFrame(id: id, function: point.function, file: point.file, line: point.line))
        } else if kind == 2 {
            if let index = stack.lastIndex(where: { $0.id == id }) { stack.removeSubrange(index...) }
        } else if !stack.isEmpty { stack[stack.count - 1].line = point.line }
        stacks[goroutine] = stack.isEmpty ? nil : stack
        let stepHit: Bool
        switch stepping {
        case .into: stepHit = kind == 0
        case .over: stepHit = kind == 0 && goroutine == baselineGoroutine && stack.count <= baselineDepth
        case .out: stepHit = kind == 0 && goroutine == baselineGoroutine && stack.count < baselineDepth
        case nil: stepHit = false
        }
        guard kind == 0, breakpoints.contains(id) || stepHit else { condition.unlock(); return }
        paused = true
        stepping = nil
        baselineDepth = stack.count
        baselineGoroutine = goroutine
        let locals = (try? JSONDecoder().decode([String: String].self, from: payload)) ?? [:]
        let snapshot = GoDebugPause(point: point, goroutine: goroutine, frames: Array(stack.reversed()), locals: locals)
        condition.unlock()
        onPause(snapshot)
        condition.lock()
        while paused && !cancelled { condition.wait() }
        let stopped = cancelled
        condition.unlock()
        if stopped { throw Stopped() }
    }

    func resume(step: Step? = nil) {
        condition.lock()
        stepping = step
        paused = false
        condition.broadcast()
        condition.unlock()
    }

    func stop() {
        condition.lock()
        cancelled = true
        paused = false
        condition.broadcast()
        condition.unlock()
    }
}

struct GoDebugInstrumented: Decodable, Sendable {
    let files: [String: String]
    let points: [GoDebugPoint]
}
