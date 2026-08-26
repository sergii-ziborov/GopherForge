import Foundation

/// One logical concurrency event from an instrumented teaching program.
///
/// These do not come from the Go scheduler. The lab's example programs import a
/// tiny instrumentation package that prints a structured line at each
/// interesting point, and the app reads those lines. That keeps the picture
/// honest: it shows what the program did, not a claim about how the runtime
/// scheduled it.
struct ConcurrencyEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case goroutineStarted = "go"
        case goroutineFinished = "done"
        case send
        case receive
        case channelClosed = "close"
        case selectChosen = "select"
        case contextCancelled = "cancel"
        case waitGroupAdd = "wg-add"
        case waitGroupDone = "wg-done"
        case waitGroupWaitReturned = "wg-wait"
        case blocked
    }

    let id = UUID()
    /// Monotonic index within the trace. The lab orders by this rather than by
    /// wall-clock time, which is not meaningful inside an interpreter.
    let sequence: Int
    let kind: Kind
    /// The goroutine label the example gave itself, for example `producer`.
    let actor: String
    /// The channel, WaitGroup or context involved, when the event has one.
    let subject: String?
    let value: String?
    let note: String?
}

extension ConcurrencyEvent {
    var isBlocking: Bool { kind == .blocked }

    var summary: String {
        switch kind {
        case .goroutineStarted: "\(actor) started"
        case .goroutineFinished: "\(actor) finished"
        case .send: "\(actor) sent \(value ?? "a value") on \(subject ?? "a channel")"
        case .receive: "\(actor) received \(value ?? "a value") from \(subject ?? "a channel")"
        case .channelClosed: "\(actor) closed \(subject ?? "a channel")"
        case .selectChosen: "\(actor) took the \(subject ?? "chosen") branch"
        case .contextCancelled: "\(subject ?? "context") was cancelled"
        case .waitGroupAdd: "\(actor) added to \(subject ?? "the WaitGroup")"
        case .waitGroupDone: "\(actor) marked done on \(subject ?? "the WaitGroup")"
        case .waitGroupWaitReturned: "\(actor) stopped waiting on \(subject ?? "the WaitGroup")"
        case .blocked: "\(actor) is blocked on \(subject ?? "something")"
        }
    }
}
