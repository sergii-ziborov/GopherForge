import UIKit

/// The column of line numbers down the left of the editor.
///
/// Drawn rather than assembled from labels: a file of a few thousand lines
/// would otherwise be a few thousand views, and only the handful on screen are
/// ever visible. The numbers are positioned from the layout manager's own line
/// fragments, so they stay aligned with the text whatever the font size — and
/// with wrapping off there is exactly one fragment per line, which is what
/// makes the alignment exact rather than approximate.
final class LineNumberGutterView: UIView {
    /// Wide enough for four digits at the editor's largest size. Fixed rather
    /// than measured: a gutter that changes width as you scroll past line 1000
    /// shifts every line of code sideways.
    static let width: CGFloat = 44

    weak var textView: UITextView? {
        didSet { setNeedsDisplay() }
    }

    var fontSize: CGFloat = 14 {
        didSet { setNeedsDisplay() }
    }

    /// Lines a diagnostic points at, marked in the gutter as well as in the
    /// text, because the gutter is where the eye goes to find a line number.
    var markedLines: Set<Int> = [] {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let textView,
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        let layoutManager = textView.layoutManager
        let container = textView.textContainer
        let inset = textView.textContainerInset
        let offset = textView.contentOffset.y

        // Only the fragments on screen: drawing the whole file would make
        // scrolling a long one cost more the further down you are.
        let visible = CGRect(
            x: 0,
            y: offset - inset.top,
            width: container.size.width,
            height: bounds.height + fontSize * 2
        )
        let range = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let text = textView.text as NSString

        let font = UIFont.monospacedDigitSystemFont(ofSize: max(9, fontSize - 2), weight: .regular)
        let firstCharacter = layoutManager.characterRange(
            forGlyphRange: NSRange(location: range.location, length: 0),
            actualGlyphRange: nil
        ).location
        var lineNumber = text.substring(to: min(firstCharacter, text.length))
            .components(separatedBy: "\n").count

        context.setFillColor(UIColor.systemOrange.withAlphaComponent(0.18).cgColor)

        layoutManager.enumerateLineFragments(forGlyphRange: range) { _, usedRect, _, glyphRange, _ in
            let y = usedRect.minY + inset.top - offset
            if self.markedLines.contains(lineNumber) {
                context.fill(CGRect(x: 0, y: y, width: self.bounds.width, height: usedRect.height))
            }
            self.draw(
                number: lineNumber,
                at: y,
                height: usedRect.height,
                font: font,
                marked: self.markedLines.contains(lineNumber)
            )
            // With wrapping off a fragment is a line, so counting fragments
            // counts lines. Kept explicit so the assumption is visible.
            lineNumber += self.lineCount(in: glyphRange, of: layoutManager, text: text)
        }
    }

    private func lineCount(
        in glyphRange: NSRange,
        of layoutManager: NSLayoutManager,
        text: NSString
    ) -> Int {
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard characterRange.length > 0, NSMaxRange(characterRange) <= text.length else { return 1 }
        return max(1, text.substring(with: characterRange).components(separatedBy: "\n").count - 1)
    }

    private func draw(number: Int, at y: CGFloat, height: CGFloat, font: UIFont, marked: Bool) {
        let string = NSAttributedString(
            string: "\(number)",
            attributes: [
                .font: font,
                .foregroundColor: marked
                    ? UIColor.systemOrange
                    : UIColor.tertiaryLabel,
            ]
        )
        let size = string.size()
        // Right-aligned, with a gap before the code: a ragged right edge on a
        // column of numbers is harder to scan than the numbers are to read.
        string.draw(
            at: CGPoint(
                x: bounds.width - size.width - 8,
                y: y + max(0, (height - size.height) / 2)
            )
        )
    }
}
