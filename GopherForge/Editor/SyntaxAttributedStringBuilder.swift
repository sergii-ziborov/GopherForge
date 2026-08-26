import SwiftUI
import UIKit

/// Turns tokens into the attributed string the text view draws.
///
/// Separated from the editor so highlighting can be tested without a view, and
/// so the tokenizer never has to know about UIKit.
struct SyntaxAttributedStringBuilder {
    let fileKind: SourceFileKind
    let fontSize: CGFloat
    var markedLines: Set<Int> = []
    var theme: GoSyntaxTheme = .standard

    func build(_ source: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributed = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(theme.plain),
            ]
        )

        for token in fileKind.tokens(in: source) {
            let nsRange = NSRange(token.range, in: source)
            guard nsRange.location != NSNotFound else { continue }
            attributed.addAttribute(
                .foregroundColor,
                value: UIColor(token.kind.color(in: theme)),
                range: nsRange
            )
        }

        applyLineMarks(to: attributed, source: source)
        return attributed
    }

    /// Marked lines get a background rather than an underline: an underline is
    /// easily mistaken for a spelling squiggle, and these are compiler facts.
    private func applyLineMarks(to attributed: NSMutableAttributedString, source: String) {
        guard !markedLines.isEmpty else { return }
        let nsSource = source as NSString
        var lineNumber = 1
        var index = 0

        while index < nsSource.length {
            let lineRange = nsSource.lineRange(for: NSRange(location: index, length: 0))
            if markedLines.contains(lineNumber) {
                attributed.addAttribute(
                    .backgroundColor,
                    value: UIColor.systemRed.withAlphaComponent(0.12),
                    range: lineRange
                )
            }
            index = NSMaxRange(lineRange)
            lineNumber += 1
            if lineRange.length == 0 { break }
        }
    }
}
