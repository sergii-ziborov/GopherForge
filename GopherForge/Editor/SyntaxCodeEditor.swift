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
        var parent: SyntaxCodeEditor
        var appliedFontSize: CGFloat = 0
        var appliedFileKind: SourceFileKind = .plain

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

        /// Go needs these characters constantly and iOS buries all of them.
        func makeAccessoryView(for textView: UITextView) -> UIView {
            let symbols = ["\t", "{", "}", "(", ")", "[", "]", ":=", "<-", "*", "&", "\"", "`"]
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.distribution = .fillEqually
            stack.spacing = 4
            stack.frame = CGRect(x: 0, y: 0, width: 0, height: 44)

            for symbol in symbols {
                let button = UIButton(type: .system)
                button.setTitle(symbol == "\t" ? "⇥" : symbol, for: .normal)
                button.titleLabel?.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
                button.addAction(
                    UIAction { [weak textView] _ in
                        textView?.insertText(symbol)
                    },
                    for: .touchUpInside
                )
                stack.addArrangedSubview(button)
            }

            let container = UIView(frame: stack.frame)
            container.backgroundColor = .secondarySystemBackground
            stack.frame = container.bounds
            stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(stack)
            return container
        }
    }
}
