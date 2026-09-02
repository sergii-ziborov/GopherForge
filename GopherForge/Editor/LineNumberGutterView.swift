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

    /// One line fragment, and which line of the file it belongs to.
    struct FragmentLine: Equatable {
        let number: Int
        /// False for the continuation of a line that wrapped, so the gutter can
        /// leave it blank the way an editor does rather than inventing a line.
        let startsLine: Bool
        let y: CGFloat
        let height: CGFloat
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let font = UIFont.monospacedDigitSystemFont(ofSize: max(9, fontSize - 2), weight: .regular)
        context.setFillColor(UIColor.systemOrange.withAlphaComponent(0.18).cgColor)

        for fragment in fragmentLines() {
            let marked = markedLines.contains(fragment.number)
            if marked {
                context.fill(CGRect(x: 0, y: fragment.y, width: bounds.width, height: fragment.height))
            }
            // A wrapped row carries no number. Two identical numbers down the
            // gutter read as two lines, which is the same lie as numbering the
            // row separately.
            guard fragment.startsLine else { continue }
            draw(number: fragment.number, at: fragment.y, height: fragment.height, font: font, marked: marked)
        }
    }

    /// The fragments on screen, each tagged with the line of the file it is
    /// part of.
    ///
    /// The number comes from the character the fragment starts at, not from a
    /// counter advanced once per fragment. Counting fragments is only right
    /// while nothing wraps, and when something does it starts numbering rows on
    /// the screen instead of lines in the file — so every number below the
    /// first long line disagrees with the compiler, and a diagnostic marks a
    /// line nobody was told about.
    ///
    /// Only what is on screen: numbering a whole file would make scrolling a
    /// long one cost more the further down you go.
    func fragmentLines() -> [FragmentLine] {
        guard let textView else { return [] }

        let layoutManager = textView.layoutManager
        let container = textView.textContainer
        let inset = textView.textContainerInset
        let offset = textView.contentOffset.y

        let visible = CGRect(
            x: 0,
            y: offset - inset.top,
            width: max(1, container.size.width),
            height: max(bounds.height, 1) + fontSize * 2
        )
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let text = textView.text as NSString

        var characterIndex = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphRange.location, length: 0),
            actualGlyphRange: nil
        ).location
        // The prefix is walked once; after that only the gap between one
        // fragment and the next is counted, so the whole pass stays linear in
        // what is on screen rather than quadratic in it.
        var lineNumber = Self.lineNumber(at: characterIndex, in: text)
        var previousNumber = 0

        var fragments: [FragmentLine] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, fragmentGlyphs, _ in
            let start = layoutManager.characterRange(
                forGlyphRange: NSRange(location: fragmentGlyphs.location, length: 0),
                actualGlyphRange: nil
            ).location
            if start > characterIndex {
                lineNumber += Self.newlineCount(
                    in: NSRange(location: characterIndex, length: start - characterIndex),
                    of: text
                )
                characterIndex = start
            }
            fragments.append(
                FragmentLine(
                    number: lineNumber,
                    startsLine: lineNumber != previousNumber,
                    y: usedRect.minY + inset.top - offset,
                    height: usedRect.height
                )
            )
            previousNumber = lineNumber
        }
        return fragments
    }

    /// The numbers this gutter would draw, in order. The invariant the editor
    /// rests on, in a shape a test can read.
    func lineNumbersForVisibleFragments() -> [Int] {
        fragmentLines().filter(\.startsLine).map(\.number)
    }

    /// Lines are counted from the newlines before a character, which is what
    /// every compiler means by a line number.
    static func lineNumber(at characterIndex: Int, in text: NSString) -> Int {
        let bounded = max(0, min(characterIndex, text.length))
        return 1 + newlineCount(in: NSRange(location: 0, length: bounded), of: text)
    }

    static func newlineCount(in range: NSRange, of text: NSString) -> Int {
        guard range.length > 0, NSMaxRange(range) <= text.length else { return 0 }
        var count = 0
        var remaining = range
        while remaining.length > 0 {
            let found = text.range(of: "\n", options: [], range: remaining)
            guard found.location != NSNotFound else { break }
            count += 1
            let next = NSMaxRange(found)
            remaining = NSRange(location: next, length: max(0, NSMaxRange(range) - next))
        }
        return count
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
