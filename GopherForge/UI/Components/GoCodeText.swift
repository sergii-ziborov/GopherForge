import SwiftUI

/// Read-only Go source, highlighted with the same tokenizer the editor uses.
///
/// Sharing the tokenizer matters: sample code that is coloured differently from
/// the editor teaches the reader that the colours mean nothing.
struct GoCodeText: View {
    let code: String
    var fileKind: SourceFileKind = .go
    var fontSize: CGFloat = 13

    /// Wrapping a line of Go hides its own indentation and makes every line
    /// under it start somewhere different. Sideways is the right direction for
    /// code, and a swipe is cheaper than a misread block.
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(attributed)
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 8)
        }
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
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Skipped when empty rather than drawn as a blank line: the block
            // is used inside titled sections now, where a second title would
            // be the same words twice.
            HStack {
                if !title.isEmpty {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    expanded = true
                } label: {
                    Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.weight(.semibold))
                }
                .accessibilityLabel("Open code in full screen")
            }
            GoCodeText(code: code, fileKind: fileKind)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .fullScreenCover(isPresented: $expanded) {
            NavigationStack {
                ScrollView([.horizontal, .vertical]) {
                    Text(AttributedString(SyntaxAttributedStringBuilder(fileKind: fileKind, fontSize: 14).build(code)))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(title.isEmpty ? "Code" : title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.down") { expanded = false }
                    }
                }
            }
        }
    }
}
