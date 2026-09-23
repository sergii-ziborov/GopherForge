import SwiftUI

/// The example library: small programs that each show one thing, and that each
/// provably run.
struct ExampleLibraryView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(AppNavigation.self) private var navigation
    /// Narrows the list to a concept when the library is opened from a review
    /// item or a diagnostic rather than from the menu.
    let conceptTag: String?

    init(conceptTag: String? = nil) {
        self.conceptTag = conceptTag
    }

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.examples) { example in
                        NavigationLink {
                            ExampleDetailView(example: example, onOpen: open)
                        } label: {
                            ExampleRow(example: example)
                        }
                        .accessibilityIdentifier("example.\(example.id)")
                    }
                }
            }
        }
        .navigationTitle(conceptTag.map { "Examples · \($0)" } ?? "Examples")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sections: [(title: String, examples: [GoExample])] {
        guard let conceptTag else { return GoExampleLibrary.sections }
        let matching = GoExampleLibrary.examples(forConcept: conceptTag)
        return matching.isEmpty ? GoExampleLibrary.sections : [("Matching this concept", matching)]
    }

    /// Opening an example puts it in the workspace as an ordinary project, so
    /// it can be edited and broken — which is most of what an example is for.
    private func open(_ example: GoExample) {
        if workspace.open(example.project()) { navigation.section = .build }
    }
}

struct ExampleRow: View {
    let example: GoExample

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(example.title).font(.callout.weight(.medium))
                if example.servesSite {
                    Text("SITE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if example.producesImage {
                    Text("PIC")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.teal)
                }
            }
            Text(example.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

/// One example: what it shows, the code, and what it prints.
struct ExampleDetailView: View {
    let example: GoExample
    let onOpen: (GoExample) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(example.summary).font(.subheadline)

                Label(example.takeaway, systemImage: "lightbulb")
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                Button {
                    onOpen(example)
                } label: {
                    Label("Open in workspace", systemImage: "hammer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.exampleOpen)

                if example.servesSite {
                    Label("In Code, tap Run to build this Gin preview. The site then appears in Output.",
                          systemImage: "play.rectangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SourceBlock(title: "main.go", text: example.source)
                ForEach(pageFiles, id: \.path) { file in
                    SourceBlock(title: file.path, text: file.text)
                }
                SourceBlock(title: "Output", text: example.expectedOutput)

            }
            .padding(16)
        }
        .navigationTitle(example.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageFiles: [(path: String, text: String)] {
        example.extraFiles
            .filter { path, _ in
                let kind = SourceFileKind.of(path: path)
                return kind == .html || kind == .javascript || kind == .css || kind == .json
            }
            .map { (path: $0.key, text: $0.value) }
            .sorted { $0.path < $1.path }
    }
}

/// Code and output, both monospaced, both scrolling sideways rather than
/// wrapping — a wrapped Go line is harder to read than a scrolled one.
private struct SourceBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
