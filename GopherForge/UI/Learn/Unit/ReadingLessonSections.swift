import SwiftUI

struct ReadingLessonSections: View {
    let reading: ReadingLesson
    let tint: Color

    private func kind(for language: String?) -> SourceFileKind {
        switch language {
        case "go": .go
        case "bash", "shell": .shell
        case "yaml": .yaml
        case "dockerfile": .dockerfile
        case "json": .json
        case "javascript": .javascript
        default: .plain
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Read and understand · No compilation required", systemImage: "book.pages")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            if let guide = reading.designGuide {
                ReadingDesignGuide(guide: guide, tint: tint)
            }
            ForEach(Array(reading.sections.enumerated()), id: \.offset) { index, section in
                LessonSection(title: section.title, systemImage: "text.book.closed", tint: tint) {
                    LearningProse(text: section.body)
                    if let code = section.code {
                        CodeBlock(title: "Worked example · \(section.language ?? "text")",
                                  code: code, fileKind: kind(for: section.language))
                    }
                    if let walkthrough = section.walkthrough { LearningProse(text: walkthrough) }
                }
                .accessibilityIdentifier("reading.section.\(index)")
            }
            LessonSection(title: "Remember", systemImage: "lightbulb", tint: tint) {
                LearningProse(text: reading.takeaway)
            }
            if ["operations", "containers", "kubernetes", "datastores", "modules", "services"].contains(reading.unitID) {
                Text("Read these examples here; run shell commands, containers and network services in your own development environment.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("References").font(.caption.weight(.semibold))
                ForEach(reading.references, id: \.absoluteString) { url in
                    Link((url.host ?? "Reference") + url.path, destination: url)
                        .font(.caption)
                        .accessibilityLabel("Reference: \(url.absoluteString)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.reading")
    }
}
