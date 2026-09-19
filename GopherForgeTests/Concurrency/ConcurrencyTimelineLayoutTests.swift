import XCTest
@testable import GopherForge

/// Where the blocked bars go on the lab's timeline.
///
/// The case worth pinning is the one the lab exists for: a goroutine that
/// blocked and never came back. Its bar has to run off the end of the chart,
/// because a bar that stops looks exactly like a goroutine that carried on.
final class ConcurrencyTimelineLayoutTests: XCTestCase {
    private func event(
        _ sequence: Int,
        _ kind: ConcurrencyEvent.Kind,
        _ actor: String,
        subject: String? = nil
    ) -> ConcurrencyEvent {
        ConcurrencyEvent(
            sequence: sequence,
            kind: kind,
            actor: actor,
            subject: subject,
            value: nil,
            note: nil
        )
    }

    func testABlockedGoroutineThatResumesGetsABarEndingWhereItResumed() {
        let events = [
            event(1, .goroutineStarted, "main"),
            event(2, .blocked, "main", subject: "ready"),
            event(3, .goroutineStarted, "greeter"),
            event(4, .send, "greeter", subject: "ready"),
            event(5, .receive, "main", subject: "ready"),
        ]

        let spans = ConcurrencyTimelineLayout.blockedSpans(for: "main", in: events)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].start, 1, "the bar starts where main blocked")
        XCTAssertEqual(spans[0].end, 4, "and ends at main's own next event, not the greeter's")
        XCTAssertTrue(spans[0].resumed)
    }

    func testAGoroutineThatNeverComesBackGetsABarWithNoEnd() {
        let events = [
            event(1, .goroutineStarted, "listener"),
            event(2, .blocked, "listener", subject: "updates"),
            event(3, .goroutineStarted, "main"),
            event(4, .goroutineFinished, "main"),
        ]

        let spans = ConcurrencyTimelineLayout.blockedSpans(for: "listener", in: events)

        XCTAssertEqual(spans.count, 1)
        XCTAssertNil(spans[0].end, "nothing the listener did follows the block")
        XCTAssertFalse(spans[0].resumed)
    }

    /// An unended bar has to reach the end of the chart. Drawn any shorter it
    /// would say the goroutine got going again.
    func testAnUnendedBarIsWiderThanOneThatResumedImmediately() {
        let events = [
            event(1, .blocked, "stuck", subject: "forever"),
            event(2, .goroutineStarted, "other"),
            event(3, .goroutineStarted, "other"),
            event(4, .goroutineFinished, "other"),
        ]
        let stuck = ConcurrencyTimelineLayout.blockedSpans(for: "stuck", in: events)[0]

        let resumedEvents = [
            event(1, .blocked, "brief", subject: "ready"),
            event(2, .receive, "brief", subject: "ready"),
        ]
        let brief = ConcurrencyTimelineLayout.blockedSpans(for: "brief", in: resumedEvents)[0]

        XCTAssertGreaterThan(stuck.width(stepWidth: 58), brief.width(stepWidth: 58))
    }

    func testAGoroutineThatBlockedTwiceGetsTwoBars() {
        let events = [
            event(1, .blocked, "main", subject: "first"),
            event(2, .receive, "main", subject: "first"),
            event(3, .blocked, "main", subject: "second"),
            event(4, .receive, "main", subject: "second"),
        ]

        XCTAssertEqual(ConcurrencyTimelineLayout.blockedSpans(for: "main", in: events).count, 2)
    }
}
