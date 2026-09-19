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
        if element.waitForExistence(timeout: timeout), isOnScreen(element) { return true }

        // Existing is not the same as reachable: a row that scrolled in at the
        // very bottom exists and cannot be tapped, and a test that taps it
        // anyway fails somewhere else entirely.
        for _ in 0..<attempts {
            if element.exists, isOnScreen(element) { return true }
            swipeUp()
        }
        return element.exists && isOnScreen(element)
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
            // Start past the phone Files-drawer edge (72 pt). A drag that
            // begins at 15% of a 440-pt phone is a leading-edge flick and
            // opens the tree over the chip this is trying to reach.
            let leading = max(window.width * 0.15, 80)
            let trailing = window.width * 0.85
            drag(
                fromX: isPastTheRightEdge ? trailing : leading,
                toX: isPastTheRightEdge ? leading : trailing,
                atY: rowMidY
            )
        }
        return isOnScreen(element)
    }

    /// Taps a chip that may sit in a horizontal scroller.
    ///
    /// XCUITest will refuse `tap()` on a control that exists, has a real frame,
    /// and is still not hittable — a SwiftUI `ScrollView` row does this on some
    /// simulator sizes. Hitting the centre of that frame is what a finger does.
    @discardableResult
    func tapReachable(_ element: XCUIElement) -> Bool {
        guard scrollHorizontally(to: element) || element.exists else { return false }
        if element.isHittable {
            element.tap()
            return true
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
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

    /// Waits for an element to report itself selected.
    ///
    /// Selection animates, and asking the instant after a tap makes a test that
    /// passes alone and fails in a suite — where the app has more to do and
    /// every transition takes longer.
    func waitForSelection(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isSelected { return true }
            _ = element.waitForExistence(timeout: 0.2)
        }
        return element.isSelected
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
