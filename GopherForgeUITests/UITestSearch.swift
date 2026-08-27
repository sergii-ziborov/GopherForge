import XCTest

/// Finding things the way a person would.
///
/// SwiftUI builds list rows lazily, so an element below the fold does not exist
/// in the hierarchy at all — not hidden, absent. A test that only waits for it
/// is really asserting that the content happens to fit this screen, which is a
/// claim about the simulator rather than about the app, and it breaks the first
/// time a section is added above.
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

    /// An element by identifier regardless of the trait SwiftUI gave it.
    ///
    /// A container that carries an identifier can surface as `other`, `group`
    /// or a plain static text depending on what is inside it, and a test that
    /// guesses wrong reports "missing" for something plainly on screen.
    func element(withIdentifier identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
