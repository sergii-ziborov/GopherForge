import SwiftUI
import UIKit

/// The editable code view.
///
/// A `UITextView` rather than a SwiftUI `TextEditor` because the product needs
/// three things SwiftUI does not give: attributed re-highlighting without
/// losing the selection, a caret position the app can read, and a keyboard
/// accessory with the characters Go needs most.
struct SyntaxCodeEditor: UIViewRepresentable {
    @Binding var text: String
    let fileKind: SourceFileKind
    let fontSize: CGFloat
    /// Lines to mark, keyed by line number, for example the ones a diagnostic
    /// points at.
    var markedLines: Set<Int> = []
    /// A line to scroll to and select, set when a search result is chosen.
    /// Cleared through `onReveal` once it has happened, so an ordinary redraw
    /// does not drag the reader back to it.
    var revealLine: Int?
    var onReveal: (() -> Void)?
    var onCaretLineChange: ((Int, String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
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
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        let needsTextUpdate = textView.text != text
        if needsTextUpdate {
            let selection = textView.selectedRange
            textView.attributedText = context.coordinator.highlighted(text, fontSize: fontSize)
            textView.selectedRange = Self.clamped(selection, in: textView.text)
        } else if context.coordinator.appliedFontSize != fontSize
            || context.coordinator.appliedFileKind != fileKind {
            let selection = textView.selectedRange
            textView.attributedText = context.coordinator.highlighted(text, fontSize: fontSize)
            textView.selectedRange = Self.clamped(selection, in: textView.text)
        }

        context.coordinator.appliedFontSize = fontSize
        context.coordinator.appliedFileKind = fileKind

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
        private var pendingHighlight: DispatchWorkItem?

        init(parent: SyntaxCodeEditor) {
            self.parent = parent
        }

        func highlighted(_ source: String, fontSize: CGFloat) -> NSAttributedString {
            SyntaxAttributedStringBuilder(
                fileKind: parent.fileKind,
                fontSize: fontSize,
                markedLines: parent.markedLines
            )
            .build(source)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            reportCaretLine(in: textView)
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
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportCaretLine(in: textView)
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
