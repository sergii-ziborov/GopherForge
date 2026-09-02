import SwiftUI
import UIKit

/// The editable code view.
///
/// A `UITextView` rather than a SwiftUI `TextEditor` because the product needs
/// three things SwiftUI does not give: attributed re-highlighting without
/// losing the selection, a caret position the app can read, and a keyboard
/// accessory with the characters Go needs most.
struct SyntaxCodeEditor: UIViewRepresentable {
    /// A container wide enough that nothing reaches its edge.
    ///
    /// Large and finite rather than `greatestFiniteMagnitude` because TextKit
    /// does arithmetic on this width. It is only a starting value either way:
    /// the text view overwrites it with its own width on the first layout pass,
    /// which is why `CodeEditorView` measures the string rather than the
    /// container.
    static let unboundedContainerSize = CGSize(width: 1_000_000, height: 1_000_000)

    @Binding var text: String
    let fileKind: SourceFileKind
    let fontSize: CGFloat
    /// Lines to mark, keyed by line number, for example the ones a diagnostic
    /// points at.
    var markedLines: Set<Int> = []
    /// Marked in the code, matching what the navigator's search listed.
    var searchQuery: String = ""
    /// A line to scroll to and select, set when a search result is chosen.
    /// Cleared through `onReveal` once it has happened, so an ordinary redraw
    /// does not drag the reader back to it.
    var revealLine: Int?
    var onReveal: (() -> Void)?
    var onCaretLineChange: ((Int, String) -> Void)?

    func makeUIView(context: Context) -> CodeEditorView {
        // TextKit 1 on purpose: the gutter positions each number from a line
        // fragment, and NSLayoutManager is the API that hands those over.
        let textView = UITextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.alwaysBounceVertical = true
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 24, right: 8)
        textView.inputAccessoryView = context.coordinator.makeAccessoryView(for: textView)

        // Code does not wrap. A wrapped Go line hides its own indentation and
        // makes every line below it start in a different place, which is worse
        // than scrolling sideways for the occasional long one.
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.lineBreakMode = .byClipping
        textView.textContainer.size = SyntaxCodeEditor.unboundedContainerSize
        textView.isDirectionalLockEnabled = true
        textView.showsHorizontalScrollIndicator = true
        // On the text view rather than on the SwiftUI wrapper: the wrapper is
        // now a container holding the gutter as well, and an identifier there
        // names the box instead of the thing you type into.
        textView.accessibilityIdentifier = AccessibilityID.editor

        return CodeEditorView(textView: textView)
    }

    func updateUIView(_ editor: CodeEditorView, context: Context) {
        let textView = editor.textView
        context.coordinator.parent = self
        editor.gutter.fontSize = fontSize
        editor.gutter.markedLines = markedLines

        let needsTextUpdate = textView.text != text
        if needsTextUpdate {
            let selection = textView.selectedRange
            let highlighted = context.coordinator.highlighted(text, fontSize: fontSize)
            editor.apply(highlighted, selection: Self.clamped(selection, in: highlighted.string))
        } else if context.coordinator.appliedFontSize != fontSize
            || context.coordinator.appliedFileKind != fileKind
            // Marks live in the attributed string, so a change to either set
            // repaints nothing unless the string is rebuilt — and the text is
            // exactly what has not changed when a search runs or a compile
            // finishes.
            || context.coordinator.appliedSearchQuery != searchQuery
            || context.coordinator.appliedMarkedLines != markedLines {
            let selection = textView.selectedRange
            let highlighted = context.coordinator.highlighted(text, fontSize: fontSize)
            editor.apply(highlighted, selection: Self.clamped(selection, in: highlighted.string))
        }

        context.coordinator.appliedFontSize = fontSize
        context.coordinator.appliedFileKind = fileKind
        context.coordinator.appliedSearchQuery = searchQuery
        context.coordinator.appliedMarkedLines = markedLines
        context.coordinator.gutter = editor.gutter
        context.coordinator.editor = editor
        editor.gutter.setNeedsDisplay()

        if let revealLine {
            // After the text update, and on the next turn of the run loop:
            // scrolling to a range the layout manager has not laid out yet
            // lands in the wrong place.
            DispatchQueue.main.async {
                context.coordinator.reveal(line: revealLine, in: textView)
                onReveal?()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// A re-highlight replaces the whole string, so a stale selection can point
    /// past the end. Clamping keeps the caret rather than dropping it to zero.
    private static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(range.location, length)
        return NSRange(location: location, length: min(range.length, length - location))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        /// Long enough that a fast typist is never interrupted, short enough
        /// that a word is coloured by the time the eye returns to it.
        static let highlightDelay: TimeInterval = 0.12

        var parent: SyntaxCodeEditor
        var appliedFontSize: CGFloat = 0
        var appliedFileKind: SourceFileKind = .plain
        var appliedSearchQuery = ""
        var appliedMarkedLines: Set<Int> = []
        /// Redrawn whenever the text or the scroll position changes, because
        /// the numbers are painted rather than laid out.
        weak var gutter: LineNumberGutterView?
        /// Asked to re-measure after an edit: a line that just became longer
        /// than every other one has to become reachable.
        weak var editor: CodeEditorView?
        private var pendingHighlight: DispatchWorkItem?

        init(parent: SyntaxCodeEditor) {
            self.parent = parent
        }

        func highlighted(_ source: String, fontSize: CGFloat) -> NSAttributedString {
            SyntaxAttributedStringBuilder(
                fileKind: parent.fileKind,
                fontSize: fontSize,
                markedLines: parent.markedLines,
                searchQuery: parent.searchQuery
            )
            .build(source)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            reportCaretLine(in: textView)
            editor?.updateTextWidth()
            gutter?.setNeedsDisplay()
            // Typing is the one path where SwiftUI cannot ask for a
            // re-highlight: the binding is already equal to the buffer by the
            // time updateUIView runs, so it correctly decides nothing changed.
            // Without this, everything the user types stays unstyled.
            scheduleHighlight(of: textView)
        }

        /// Re-highlights shortly after typing stops.
        ///
        /// Not on every keystroke: replacing the whole attributed string costs
        /// a full layout, and doing it mid-word on a long file is felt. A short
        /// idle delay colours a word about as fast as the eye reaches it while
        /// leaving fast typing alone.
        private func scheduleHighlight(of textView: UITextView) {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                applyHighlight(to: textView)
            }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.highlightDelay, execute: work)
        }

        private func applyHighlight(to textView: UITextView) {
            // Mid-composition the text view owns a marked range, and replacing
            // the string underneath it drops what is being composed.
            guard textView.markedTextRange == nil else { return }

            let selection = textView.selectedRange
            textView.attributedText = highlighted(textView.text, fontSize: parent.fontSize)
            textView.selectedRange = SyntaxCodeEditor.clamped(selection, in: textView.text)
            // Setting attributedText replaces the typing attributes with those
            // of the last token, so the next character would arrive wearing
            // whatever colour the previous one had.
            textView.typingAttributes = SyntaxAttributedStringBuilder.baseAttributes(
                fontSize: parent.fontSize
            )
            gutter?.setNeedsDisplay()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportCaretLine(in: textView)
        }

        /// Only the gutter: re-measuring the longest line on every scroll
        /// frame would lay the whole file out again for nothing.
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            gutter?.setNeedsDisplay()
        }

        /// The line the caret is on, and its text, which the completion and the
        /// idiom coach both work from.
        private func reportCaretLine(in textView: UITextView) {
            guard let onCaretLineChange = parent.onCaretLineChange else { return }
            let source = textView.text as NSString
            let caret = min(textView.selectedRange.location, source.length)
            let lineRange = source.lineRange(for: NSRange(location: caret, length: 0))
            let lineNumber = source
                .substring(to: lineRange.location)
                .components(separatedBy: "\n")
                .count
            let lineText = source
                .substring(with: lineRange)
                .trimmingCharacters(in: .newlines)
            onCaretLineChange(lineNumber, lineText)
        }

        /// The accessory owns its own layout and suggestion menu; the editor
        /// only supplies what it alone knows: the caret's line.
        func makeAccessoryView(for textView: UITextView) -> UIView {
            GoKeyboardAccessoryView(
                onInsert: { [weak textView] text in
                    textView?.insertText(text)
                },
                onDismiss: { [weak textView] in
                    textView?.resignFirstResponder()
                },
                suggestions: { [weak self, weak textView] in
                    guard let self, let textView else { return [] }
                    return GoCodeCompletion().suggestions(
                        for: GoCodeCompletion.Context(
                            line: currentLine(in: textView),
                            fileKind: parent.fileKind
                        )
                    )
                }
            )
        }

        /// Puts a line on screen and selects it, so a search result arrives
        /// visible rather than merely open.
        func reveal(line: Int, in textView: UITextView) {
            let source = textView.text as NSString
            var location = 0
            var current = 1
            while current < line, location < source.length {
                let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
                location = NSMaxRange(lineRange)
                current += 1
            }
            guard location <= source.length else { return }

            let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
            let selection = NSRange(
                location: lineRange.location,
                length: max(0, lineRange.length - 1)
            )
            textView.selectedRange = selection
            textView.scrollRangeToVisible(selection)
        }

        /// The text of the line the caret sits on, which is what the completion
        /// table matches against.
        private func currentLine(in textView: UITextView) -> String {
            let source = textView.text as NSString
            let caret = min(textView.selectedRange.location, source.length)
            let lineRange = source.lineRange(for: NSRange(location: caret, length: 0))
            return source.substring(with: lineRange).trimmingCharacters(in: .newlines)
        }
    }
}
