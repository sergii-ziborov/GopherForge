import CoreGraphics

/// Where a blocked goroutine's bar starts and ends on the timeline.
///
/// Held apart from the drawing so it can be tested. The interesting case is the
/// one with no end: a goroutine that blocked and never did anything again is
/// exactly the failure the lab exists to show, and a span that quietly stopped
/// at the next event of some *other* goroutine would draw that failure as if it
/// had resolved.
enum ConcurrencyTimelineLayout {
    struct BlockedSpan: Equatable {
        let start: Int
        /// The index this goroutine next did something at, or nil if it never
        /// did.
        let end: Int?
        let total: Int

        var resumed: Bool { end != nil }

        func width(stepWidth: CGFloat) -> CGFloat {
            let last = end ?? total
            return max(stepWidth * CGFloat(max(last - start, 1)) - stepWidth / 2, 14)
        }
    }

    static func blockedSpans(
        for actor: String,
        in ordered: [ConcurrencyEvent]
    ) -> [BlockedSpan] {
        var spans: [BlockedSpan] = []
        for (index, event) in ordered.enumerated() where event.actor == actor && event.isBlocking {
            let next = ordered
                .enumerated()
                .first { $0.offset > index && $0.element.actor == actor }?
                .offset
            spans.append(BlockedSpan(start: index, end: next, total: ordered.count))
        }
        return spans
    }
}
