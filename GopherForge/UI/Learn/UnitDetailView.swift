import SwiftUI

/// One unit: why it exists, then its lessons.
struct UnitDetailView: View {
    let unit: CourseUnit
    @Environment(LearnProgress.self) private var progress

    private var doneCount: Int { progress.completedCount(in: unit) }

    var body: some View {
        List {
            Section {
                UnitHeaderCard(unit: unit, done: doneCount, total: unit.teachingLessons.count)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Text(unit.translationNote)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("If you already program")
            }

            Section("Lessons") {
                ForEach(unit.teachingLessons) { lesson in
                    NavigationLink {
                        LessonDetailView(lesson: lesson)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            LessonStatusMark(
                                isCompleted: progress.isCompleted(lesson.id),
                                isCompilerVerified: progress.isCompilerVerified(lesson.id)
                            )
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
                    // The mark is a glyph, and a glyph is nothing to VoiceOver
                    // or to a test. This is the row saying what its state is.
                    .accessibilityValue(
                        LessonStatusMark.description(
                            isCompleted: progress.isCompleted(lesson.id),
                            isCompilerVerified: progress.isCompilerVerified(lesson.id)
                        )
                    )
                }
            }

        }
        .navigationTitle(unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// How a lesson's state reads in a list.
///
/// Two ticks rather than one: a seal for a pass the compiler witnessed, a plain
/// tick for one the learner reported. The app should never draw the stronger
/// mark for the weaker claim — but it should still draw a mark, because a
/// learner who has done the work deserves to see it.
struct LessonStatusMark: View {
    let isCompleted: Bool
    let isCompilerVerified: Bool

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        guard isCompleted else { return "circle" }
        return isCompilerVerified ? "checkmark.seal.fill" : "checkmark.circle.fill"
    }

    private var tint: Color {
        guard isCompleted else { return .secondary }
        return isCompilerVerified ? .green : GopherForgeTheme.anvil
    }

    /// Said in words for VoiceOver, where two similar glyphs are one glyph.
    static func description(isCompleted: Bool, isCompilerVerified: Bool) -> String {
        guard isCompleted else { return "Not done" }
        return isCompilerVerified ? "Passed the compiler" : "Marked done"
    }
}
