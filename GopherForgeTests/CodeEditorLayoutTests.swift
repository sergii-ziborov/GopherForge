import UIKit
import XCTest
@testable import GopherForge

/// The editor's promise: code scrolls sideways rather than wrapping, and the
/// gutter numbers lines of the file.
///
/// Both were broken together, and the second is the one that matters. A
/// diagnostic points at a line number; `CodeEditorView` marks that line in the
/// gutter and in the text. Once a wrapped row is counted as a line, every
/// number below the first long line is wrong, and the app marks a line the
/// compiler never mentioned.
final class CodeEditorLayoutTests: XCTestCase {
    private let paneWidth: CGFloat = 360

    /// The same text view `SyntaxCodeEditor` builds, filled in the order the
    /// app fills it: the view is laid out while it is still empty, and the text
    /// arrives afterwards.
    ///
    /// The order is the whole test. Text set before the first layout measures
    /// correctly and hides the defect completely — which is why the first
    /// version of this file passed against the broken editor.
    private func makeEditor(text: String) -> CodeEditorView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 24, right: 8)
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.lineBreakMode = .byClipping
        textView.textContainer.size = SyntaxCodeEditor.unboundedContainerSize

        let editor = CodeEditorView(textView: textView)
        editor.frame = CGRect(x: 0, y: 0, width: paneWidth, height: 600)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()

        editor.apply(
            NSAttributedString(
                string: text,
                attributes: [.font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)]
            ),
            selection: NSRange(location: 0, length: 0)
        )
        editor.layoutIfNeeded()
        return editor
    }

    private var aFileWithOneLongLine: String {
        """
        package main

        import "testing"

        func TestReverse(t *testing.T) {
        \tcases := []struct{ name, in, want string }{{name: "ascii", in: "gopher", want: "rehpog"}, {name: "empty", in: "", want: ""}}
        \t_ = cases
        }
        """
    }

    func testALongLineMakesTheTextWiderThanThePaneInsteadOfWrapping() {
        let editor = makeEditor(text: aFileWithOneLongLine)

        XCTAssertGreaterThan(
            editor.textView.bounds.width,
            paneWidth,
            "a line longer than the pane should widen the text view so the "
                + "horizontal scroll view has something to scroll"
        )
    }

    func testTheGutterNumbersSourceLinesRatherThanRowsOnScreen() {
        let editor = makeEditor(text: aFileWithOneLongLine)
        let numbers = editor.gutter.lineNumbersForVisibleFragments()

        XCTAssertEqual(
            numbers, Array(1...8),
            "the file has eight lines, so the gutter should count to eight"
        )
    }

    /// The invariant stated directly: whatever the layout does, a number in the
    /// gutter is the line a diagnostic would name.
    func testNumberingSurvivesEvenIfALineIsForcedToWrap() {
        let editor = makeEditor(text: aFileWithOneLongLine)
        // Wrapping forced on, which is the state the editor spent months in
        // without anyone noticing that the numbers had stopped matching.
        editor.textView.textContainer.widthTracksTextView = true
        editor.textView.textContainer.size = CGSize(
            width: paneWidth - LineNumberGutterView.width,
            height: .greatestFiniteMagnitude
        )
        editor.textView.layoutManager.ensureLayout(for: editor.textView.textContainer)

        let numbers = editor.gutter.lineNumbersForVisibleFragments()

        XCTAssertEqual(
            numbers.max(), 8,
            "a wrapped row is part of its line, not a line of its own"
        )
        XCTAssertEqual(
            numbers, numbers.sorted(),
            "line numbers should never go backwards down the gutter"
        )
    }
}
