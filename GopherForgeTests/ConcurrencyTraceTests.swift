import XCTest
@testable import GopherForge

final class ConcurrencyTraceTests: XCTestCase {
    func testReadsInstrumentedLinesAndLeavesOutputAlone() {
        let stdout = """
        #lab 1 go producer
        hello from the program
        #lab 2 send producer jobs 3
        """
        let events = ConcurrencyTraceReader.events(in: stdout)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[1].kind, .send)
        XCTAssertEqual(events[1].subject, "jobs")
        XCTAssertEqual(events[1].value, "3")
        XCTAssertEqual(
            ConcurrencyTraceReader.programOutput(in: stdout).trimmingCharacters(in: .whitespacesAndNewlines),
            "hello from the program"
        )
    }

    func testStuckActorIsOneThatBlockedAndNeverResumed() {
        let trace = ConcurrencyTrace(events: [
            ConcurrencyEvent(sequence: 1, kind: .goroutineStarted, actor: "listener", subject: nil, value: nil, note: nil),
            ConcurrencyEvent(sequence: 2, kind: .blocked, actor: "listener", subject: "values", value: nil, note: nil),
            ConcurrencyEvent(sequence: 3, kind: .goroutineFinished, actor: "main", subject: nil, value: nil, note: nil),
        ])
        XCTAssertEqual(trace.stuckActors, ["listener"])
    }

    func testActorThatResumedIsNotStuck() {
        let trace = ConcurrencyTrace(events: [
            ConcurrencyEvent(sequence: 1, kind: .blocked, actor: "main", subject: "ready", value: nil, note: nil),
            ConcurrencyEvent(sequence: 2, kind: .receive, actor: "main", subject: "ready", value: "hello", note: nil),
        ])
        XCTAssertTrue(trace.stuckActors.isEmpty)
    }

    func testSendAfterCloseIsReported() {
        let trace = ConcurrencyTrace(events: [
            ConcurrencyEvent(sequence: 1, kind: .channelClosed, actor: "producer", subject: "jobs", value: nil, note: nil),
            ConcurrencyEvent(sequence: 2, kind: .send, actor: "producer", subject: "jobs", value: "1", note: nil),
        ])
        XCTAssertEqual(trace.sendsAfterClose.count, 1)

        let diagnoses = ConcurrencyDiagnosis.diagnose(trace)
        XCTAssertEqual(diagnoses.first?.conceptTag, GoConcept.channelClose)
    }

    func testRuntimeDeadlockIsAttributedToTheRuntime() {
        let diagnoses = ConcurrencyDiagnosis.diagnose(
            ConcurrencyTrace(events: []),
            runtimeStderr: "fatal error: all goroutines are asleep - deadlock!"
        )
        XCTAssertEqual(diagnoses.first?.conceptTag, GoConcept.deadlock)
        XCTAssertTrue(diagnoses.first?.detail.contains("runtime's own report") ?? false)
    }

    func testBufferDepthTracksSendsAndReceives() {
        let trace = ConcurrencyTrace(events: [
            ConcurrencyEvent(sequence: 1, kind: .send, actor: "p", subject: "jobs", value: "1", note: nil),
            ConcurrencyEvent(sequence: 2, kind: .send, actor: "p", subject: "jobs", value: "2", note: nil),
            ConcurrencyEvent(sequence: 3, kind: .receive, actor: "c", subject: "jobs", value: "1", note: nil),
        ])
        XCTAssertEqual(trace.bufferDepths(upTo: 3)["jobs"], 1)
        XCTAssertEqual(trace.bufferDepths(upTo: 2)["jobs"], 2)
    }
}
