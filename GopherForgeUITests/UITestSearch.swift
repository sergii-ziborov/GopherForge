import XCTest

/// Finding things the way a person would.
///
/// SwiftUI builds list rows lazily, so an element below the fold does not exist
/// in the hierarchy at all — not hidden, absent. A test that only waits for it
/// is really asserting that the content happens to fit this screen, which is a
/// claim about the simulator rather than about the app.
extension XCUIApplication {
    /// Waits for an element, scrolling the screen if it has not appeared.
    ///
    /// The scroll is bounded: this is a search, and a search that never gives
    /// up is a hang rather than a failure.
    func waitForElement(
        _ element: XCUIElement,
        scrollingUpTo attempts: Int = 6,
        timeout: TimeInterval = 10
    ) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }

        for _ in 0..<attempts {
            swipeUp()
            if element.exists { return true }
        }
        return false
    }

    /// Brings a tab into view by dragging across the row it sits in.
    ///
    /// Neither the tab nor its neighbours can be swiped: an element outside a
    /// scroll view's visible rectangle has an empty *visible* frame — even
    /// though `frame` still reports where it would be — and XCUITest refuses a
    /// gesture on one. A drag at the row's own height is what a finger does,
    /// and it works whatever the scroll position.
    func scrollHorizontally(to element: XCUIElement, attempts: Int = 8) -> Bool {
        guard element.waitForExistence(timeout: 10) else { return false }
        let window = windows.firstMatch.frame
        // Frames are reported for clipped elements too, so the row's height is
        // readable from the target itself while it is still off screen.
        let rowMidY = element.frame.midY
        guard rowMidY > 0, rowMidY < window.height else { return false }

        for _ in 0..<attempts {
            if isOnScreen(element) { return true }
            let isPastTheRightEdge = element.frame.midX > window.maxX
            drag(
                fromX: window.width * (isPastTheRightEdge ? 0.85 : 0.15),
                toX: window.width * (isPastTheRightEdge ? 0.15 : 0.85),
                atY: rowMidY
            )
        }
        return isOnScreen(element)
    }

    /// The whole frame inside the window, not just its centre: a chip half over
    /// the edge is one a tap can miss, and a test that taps it is testing the
    /// simulator's rounding rather than the app.
    func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard !frame.isEmpty else { return false }
        return windows.firstMatch.frame.insetBy(dx: 2, dy: 0).contains(frame)
    }

    /// An element by identifier regardless of the trait SwiftUI gave it.
    ///
    /// A container that carries an identifier can surface as `other`, `group`
    /// or a plain static text depending on what is inside it, and a test that
    /// guesses wrong reports "missing" for something plainly on screen.
    func element(withIdentifier identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }

    private func drag(fromX: CGFloat, toX: CGFloat, atY y: CGFloat) {
        let origin = coordinate(withNormalizedOffset: .zero)
        origin
            .withOffset(CGVector(dx: fromX, dy: y))
            .press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: toX, dy: y))
            )
    }
}
