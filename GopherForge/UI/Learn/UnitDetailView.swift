import SwiftUI

/// One unit: why it exists, then its lessons as a path.
///
/// The same shape as the course above it, one level down — so "where am I"
/// is answered the same way whether you are looking at seven units or at the
/// six lessons inside one of them.
struct UnitDetailView: View {
    let unit: CourseUnit
    @Environment(LearnProgress.self) private var progress

    private var lessons: [Lesson] { unit.teachingLessons }
    private var doneCount: Int { progress.completedCount(in: unit) }

    private var tint: Color { CourseUnitStyle.tint(for: unit.id) }

    /// The first lesson still to do — the one the path marks.
    private var nextLessonID: String? {
        lessons.first { !progress.isCompleted($0.id) }?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                UnitHeaderCard(unit: unit, done: doneCount, total: lessons.count)

                TranslationNoteCard(note: unit.translationNote, tint: tint)

                lessonPath
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lessonPath: some View {
        // Decided here, in `body`, rather than inside the path's
        // `GeometryReader` — see CoursePathItem for why that distinction is a
        // correctness one rather than a stylistic one.
        let items = lessons.map { lesson in
            CoursePathItem(
                id: lesson.id,
                title: lesson.title,
                subtitle: lesson.objective,
                badge: badge(for: lesson),
                symbol: symbol(for: lesson),
                state: state(for: lesson),
                tint: tint,
                accessibilityIdentifier: AccessibilityID.lesson(lesson.id),
                // The mark is a glyph, and a glyph is nothing to VoiceOver or
                // to a test. This is the node saying what its state is.
                accessibilityValue: LessonStatusMark.description(
                    isCompleted: progress.isCompleted(lesson.id),
                    isCompilerVerified: progress.isCompilerVerified(lesson.id)
                )
            )
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Lessons")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            CoursePathView(items: items, trailTint: tint) { item in
                if let lesson = GoCourseCatalog.lesson(id: item.id) {
                    LessonDetailView(lesson: lesson)
                }
            }
        }
    }

    private func state(for lesson: Lesson) -> CoursePathState {
        if progress.isCompilerVerified(lesson.id) { return .verified }
        if progress.isCompleted(lesson.id) { return .done }
        return lesson.id == nextLessonID ? .next : .upcoming
    }

    /// A lesson the compiler judges is worth saying so before it is opened:
    /// it is the difference between reading and building.
    private func badge(for lesson: Lesson) -> String {
        if progress.isCompilerVerified(lesson.id) { return "COMPILER PASSED" }
        if progress.isCompleted(lesson.id) { return "DONE" }
        return lesson.requiresCompiler ? "COMPILE" : "READ"
    }

    private func symbol(for lesson: Lesson) -> String {
        lesson.requiresCompiler ? "hammer.fill" : "text.book.closed.fill"
    }
}

/// The note written for someone carrying habits from another language, kept at
/// the top of the unit where it is read before the lessons rather than after.
private struct TranslationNoteCard: View {
    let note: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("If you already program", systemImage: "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(note)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// How a lesson's state reads.
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
        return isCompilerVerified ? .green : GopherForgeTheme.slate
    }

    /// Said in words for VoiceOver, where two similar glyphs are one glyph.
    static func description(isCompleted: Bool, isCompilerVerified: Bool) -> String {
        guard isCompleted else { return "Not done" }
        return isCompilerVerified ? "Passed the compiler" : "Marked done"
    }
}
