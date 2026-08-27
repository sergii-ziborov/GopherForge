import SwiftUI

/// One unit: why it exists, then its lessons.
struct UnitDetailView: View {
    let unit: CourseUnit
    let completed: Set<String>

    var body: some View {
        List {
            Section {
                Text(unit.translationNote)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("If you already program")
            }

            Section("Lessons") {
                ForEach(unit.lessons) { lesson in
                    NavigationLink {
                        LessonDetailView(lesson: lesson)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: completed.contains(lesson.id)
                                ? "checkmark.circle.fill"
                                : "circle")
                                .foregroundStyle(completed.contains(lesson.id)
                                    ? Color.green
                                    : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title).font(.callout.weight(.medium))
                                Text(lesson.objective)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.lesson(lesson.id))
                }
            }
        }
        .navigationTitle(unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
