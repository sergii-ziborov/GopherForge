import SwiftUI

/// Read-only Go source, highlighted with the same tokenizer the editor uses.
///
/// Sharing the tokenizer matters: sample code that is coloured differently from
/// the editor teaches the reader that the colours mean nothing.
struct GoCodeText: View {
    let code: String
    var fileKind: SourceFileKind = .go
    var fontSize: CGFloat = 13

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        let builder = SyntaxAttributedStringBuilder(fileKind: fileKind, fontSize: fontSize)
        return AttributedString(builder.build(code))
    }
}

/// A titled block of read-only code.
struct CodeBlock: View {
    let title: String
    let code: String
    var fileKind: SourceFileKind = .go

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            GoCodeText(code: code, fileKind: fileKind)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
