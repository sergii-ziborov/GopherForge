import UIKit

/// The editor as one view: a fixed gutter of line numbers, and code that
/// scrolls sideways rather than wrapping.
///
/// The horizontal scroll view is not optional decoration. Telling a UITextView
/// not to wrap — a huge text container and `widthTracksTextView = false` — does
/// not survive its own layout pass: it resets the container to the view's width
/// and wraps anyway. Putting the text view inside a horizontal scroll view and
/// giving it the width of its longest line is what actually stops it.
///
/// The gutter sits outside that scroll view, so the numbers stay put while the
/// code moves. Line numbers that slide off the left edge when you scroll to the
/// end of a long line would be worse than none.
final class CodeEditorView: UIView {
    let textView: UITextView
    let gutter = LineNumberGutterView()

    private let horizontalScroll = UIScrollView()
    private var textWidth: NSLayoutConstraint?

    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)

        gutter.textView = textView
        horizontalScroll.showsHorizontalScrollIndicator = true
        horizontalScroll.showsVerticalScrollIndicator = false
        horizontalScroll.alwaysBounceHorizontal = false
        horizontalScroll.isDirectionalLockEnabled = true
        horizontalScroll.delegate = nil

        addSubview(gutter)
        addSubview(horizontalScroll)
        horizontalScroll.addSubview(textView)

        for view in [gutter, horizontalScroll, textView] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        let width = textView.widthAnchor.constraint(equalToConstant: 320)
        textWidth = width

        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: LineNumberGutterView.width),

            horizontalScroll.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            horizontalScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            horizontalScroll.topAnchor.constraint(equalTo: topAnchor),
            horizontalScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            textView.leadingAnchor.constraint(equalTo: horizontalScroll.contentLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: horizontalScroll.contentLayoutGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: horizontalScroll.contentLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: horizontalScroll.contentLayoutGuide.bottomAnchor),
            textView.heightAnchor.constraint(equalTo: horizontalScroll.frameLayoutGuide.heightAnchor),
            width,
        ])

        addSeparator()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the text, then re-measures and redraws the gutter.
    ///
    /// The one door on purpose. A caller that assigns `textView.attributedText`
    /// itself and forgets to re-measure leaves the view at whatever width it
    /// had while the text was something else — and the first width it ever has
    /// is the one it was given while empty, which is the pane. The container
    /// then takes that width and every long line wraps inside it for good.
    func apply(_ attributed: NSAttributedString, selection: NSRange) {
        textView.attributedText = attributed
        textView.selectedRange = selection
        updateTextWidth()
        gutter.setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextWidth()
        gutter.setNeedsDisplay()
    }

    /// The text view is as wide as its longest line, or as wide as the space
    /// available — whichever is more, so short files do not leave a gap and
    /// long lines are reachable.
    func updateTextWidth() {
        let available = max(0, bounds.width - LineNumberGutterView.width)
        let inset = textView.textContainerInset.left + textView.textContainerInset.right
        let wanted = max(available, longestLineWidth() + inset + 24)

        guard abs((textWidth?.constant ?? 0) - wanted) > 0.5 else { return }
        textWidth?.constant = wanted
        // Changing a constant is a request, not a layout. Without this the new
        // width sits in the constraint unapplied until something else happens
        // to lay the view out — which, for an editor that has just been handed
        // a file, is nothing.
        setNeedsLayout()
    }

    /// The width of the longest line, measured from the text itself.
    ///
    /// Not from `usedRect`, which is what this used to do. A `UITextView`
    /// resets its text container to its own width on every layout pass whatever
    /// `widthTracksTextView` says — measured here, a container set to a million
    /// points came back at 330 — so the used rect reports the width of text
    /// that has already wrapped. Sizing the view from that is a loop whose
    /// fixed point is "stay wrapped": the measurement and the thing being
    /// measured are the same number, and the view never gets wide enough to
    /// stop wrapping. Measuring the string is independent of all of it.
    ///
    /// Candidates are picked by a cheap estimate and only a few are measured
    /// properly, because this runs on every layout pass and a file of a few
    /// thousand lines would otherwise be a few thousand measurements each time.
    private func longestLineWidth() -> CGFloat {
        guard let attributed = textView.attributedText, attributed.length > 0 else { return 0 }
        let text = attributed.string as NSString

        var candidates: [(estimate: Int, range: NSRange)] = []
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: text.length),
            options: [.byLines, .substringNotRequired]
        ) { _, range, _, _ in
            // A tab is one character and much more than one character wide, so
            // counting characters alone would nominate the wrong line in Go
            // source, which is indented with them.
            var tabs = 0
            for index in range.location..<NSMaxRange(range)
            where text.character(at: index) == 9 {
                tabs += 1
            }
            candidates.append((range.length + tabs * 7, range))
        }

        var widest: CGFloat = 0
        for candidate in candidates.sorted(by: { $0.estimate > $1.estimate }).prefix(4) {
            let line = attributed.attributedSubstring(from: candidate.range)
            widest = max(widest, ceil(line.size().width))
        }
        return widest
    }

    private func addSeparator() {
        // A hairline between the numbers and the code, so the gutter reads as a
        // margin rather than as the first column of the file.
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            separator.widthAnchor.constraint(equalToConstant: 0.5),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
