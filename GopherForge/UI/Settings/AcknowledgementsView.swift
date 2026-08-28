import SwiftUI

/// The third-party notices, read from the copy that actually ships.
///
/// Rendered from the bundled file rather than retyped into Swift, because a
/// licence notice that has drifted from the file it claims to be is worse than
/// no screen at all. `ThirdPartyNoticesTests` checks that every dependency the
/// project declares appears in it.
struct AcknowledgementsView: View {
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(rendered)
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .task { text = ThirdPartyNotices.text() }
    }

    /// Markdown when it parses, and the raw text when it does not — a notice
    /// must be readable even if the formatting fails.
    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Reads the bundled notices.
enum ThirdPartyNotices {
    static let resourceName = "ThirdPartyNotices"

    static func text(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: resourceName, withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            // Never silently blank: a missing notice is a packaging fault and
            // should read as one.
            return "The third-party notices are missing from this build. "
                + "This is a packaging fault; please report it."
        }
        return contents
    }
}
