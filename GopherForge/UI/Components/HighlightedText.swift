import SwiftUI

/// Text with every occurrence of a query marked.
///
/// Search that only lists results makes the reader find the word again by eye,
/// once per row. Marking it is the difference between a list of files and an
/// answer to the question that was asked.
///
/// Built on `AttributedString` rather than on stacked `Text` runs so the line
/// still wraps, truncates and reads to VoiceOver as one string.
struct HighlightedText: View {
    let text: String
    let query: String
    var font: Font = .caption2.monospaced()
    var tint: Color = GopherForgeTheme.ember

    var body: some View {
        Text(Self.attributed(text, marking: query, tint: tint))
            .font(font)
    }

    /// Marks the query wherever it appears, leaving the rest alone.
    ///
    /// `nonisolated` and static so the same string can be built for the editor,
    /// which needs the attributes without a view.
    static func attributed(
        _ text: String,
        marking query: String,
        tint: Color = GopherForgeTheme.ember
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .secondary

        for range in ProjectFileSearch.ranges(of: query, in: text) {
            // Ranges are computed against the plain string, so they have to be
            // carried across into the attributed one, which indexes differently.
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else {
                continue
            }
            attributed[lower..<upper].foregroundColor = tint
            attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        }

        return attributed
    }
}
