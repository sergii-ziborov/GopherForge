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
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        let used = textView.layoutManager.usedRect(for: textView.textContainer).width
        let wanted = max(available, ceil(used) + inset + 24)

        guard abs((textWidth?.constant ?? 0) - wanted) > 0.5 else { return }
        textWidth?.constant = wanted
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
