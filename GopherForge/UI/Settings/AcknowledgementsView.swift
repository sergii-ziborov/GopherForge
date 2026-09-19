import SwiftUI

/// The third-party notices, read from the copy that actually ships.
///
/// Grouped by licence family so a reviewer can match MIT, Apache-2.0, BSD
/// and unknown/user-vendored terms without reading a wall of markdown.
/// The text still comes from the bundled file; `ThirdPartyNoticesTests`
/// checks that every dependency the project declares appears in it.
struct AcknowledgementsView: View {
    @State private var text = ""

    var body: some View {
        let families = ThirdPartyLibrary.families(in: text)
        Group {
            if families.isEmpty {
                ScrollView {
                    Text(rendered)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                List {
                    ForEach(families) { family in
                        Section {
                            if !family.blurb.isEmpty {
                                Text(family.blurb)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(family.components) { component in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(component.name)
                                        .font(.headline)
                                    Text(component.licence)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    if !component.summary.isEmpty {
                                        Text(component.summary)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .accessibilityElement(children: .combine)
                            }
                        } header: {
                            Text(family.heading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Third-Party Library")
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
