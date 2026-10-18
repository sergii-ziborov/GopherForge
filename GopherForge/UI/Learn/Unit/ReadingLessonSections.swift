import SwiftUI

struct ReadingLessonSections: View {
    let reading: ReadingLesson
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Read and understand · No compilation required", systemImage: "book.pages")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            ForEach(Array(reading.sections.enumerated()), id: \.offset) { index, section in
                LessonSection(title: section.title, systemImage: "text.book.closed", tint: tint) {
                    LearningProse(text: section.body)
                    if let code = section.code {
                        CodeBlock(title: "Worked example · \(section.language ?? "text")",
                                  code: code, fileKind: section.language == "go" ? .go : .plain)
                    }
                    if let walkthrough = section.walkthrough { LearningProse(text: walkthrough) }
                }
                .accessibilityIdentifier("reading.section.\(index)")
            }
            LessonSection(title: "Remember", systemImage: "lightbulb", tint: tint) {
                LearningProse(text: reading.takeaway)
            }
            if reading.unitID == "operations" || reading.unitID == "services" {
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
