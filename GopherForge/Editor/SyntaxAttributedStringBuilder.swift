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
    /// What the navigator's search matched, marked in the code so the reader
    /// does not have to find the word again by eye after tapping a result.
    var searchQuery: String = ""
    var theme: GoSyntaxTheme = .standard

    /// The attributes unhighlighted text wears.
    ///
    /// Shared with the editor's typing attributes: after the whole string is
    /// replaced, the text view keeps the attributes of whatever token ended it,
    /// and the next character typed would arrive in that colour.
    static func baseAttributes(
        fontSize: CGFloat,
        theme: GoSyntaxTheme = .standard
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor(theme.plain),
        ]
    }

    func build(_ source: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: source,
            attributes: Self.baseAttributes(fontSize: fontSize, theme: theme)
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
        applySearchMarks(to: attributed, source: source)
        return attributed
    }

    /// Search hits get their own colour, distinct from the red of a compiler
    /// mark: one says "look here", the other says "this is wrong", and a reader
    /// should never have to work out which.
    private func applySearchMarks(to attributed: NSMutableAttributedString, source: String) {
        for range in ProjectFileSearch.ranges(of: searchQuery, in: source) {
            let nsRange = NSRange(range, in: source)
            guard nsRange.location != NSNotFound else { continue }
            attributed.addAttribute(
                .backgroundColor,
                value: UIColor.systemYellow.withAlphaComponent(0.28),
                range: nsRange
            )
        }
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
