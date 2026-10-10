import SwiftUI

/// Inline code uses the editor's Go palette; fenced examples are real code blocks.
struct LearningProse: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(LearningText.blocks(in: text).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .paragraph(prose):
                    Text(Self.inline(prose))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                case let .code(code):
                    CodeBlock(title: "Go", code: code)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func inline(_ text: String) -> AttributedString {
        guard let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else { return AttributedString(text) }
        var result = AttributedString()
        for run in parsed.runs {
            let piece = AttributedString(parsed[run.range])
            if run.inlinePresentationIntent?.contains(.code) == true {
                let code = String(piece.characters)
                result += AttributedString(SyntaxAttributedStringBuilder(fileKind: .go, fontSize: 13).build(code))
            } else {
                result += piece
            }
        }
        return result
    }
}
