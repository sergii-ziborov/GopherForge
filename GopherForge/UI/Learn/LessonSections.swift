import SwiftUI

/// The card at the top of a lesson: where you are, and what you will be able
/// to do afterwards.
///
/// The objective used to be a bare headline over a paragraph, with the unit and
/// the position nowhere on the page — so a lesson opened from the path gave no
/// sense of being third of five in Go core rather than adrift in a course of
/// forty.
struct LessonHeaderCard: View {
    let lesson: Lesson
    let unitTitle: String
    let position: (index: Int, total: Int)?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(unitTitle.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                if let position {
                    Text("LESSON \(position.index + 1) OF \(position.total)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Text(lesson.requiresCompiler ? "COMPILE" : "READ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.22), in: Capsule())
                    .foregroundStyle(.white)
            }

            Text(lesson.objective)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if !lesson.conceptTags.isEmpty {
                Text(lesson.conceptTags.joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint.darkened(by: 0.26), tint.darkened(by: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

/// A titled block, so the page reads as sections rather than as one column of
/// paragraphs all shouting equally.
struct LessonSection<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = GopherForgeTheme.accent
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What to do when the lesson is behind you.
///
/// The course used to end a lesson with nothing at all: a tick, and then the
/// reader's own idea to press Back, find the unit, and hunt down the node they
/// had not done. A lesson that knows what comes after it should say so.
struct LessonNextStep: View {
    let next: Lesson?
    let isFinished: Bool

    var body: some View {
        if let next {
            NavigationLink {
                LessonDetailView(lesson: next)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isFinished ? "Next lesson" : "Skip ahead")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isFinished ? .white.opacity(0.85) : .secondary)
                        Text(next.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(isFinished ? .white : .primary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(isFinished ? .white : GopherForgeTheme.accent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.lessonNext)
        } else {
            // The last teaching lesson in the course. Saying so beats a dead
            // end where every other lesson had a way onward.
            Label("That is the last lesson in the course.", systemImage: "flag.checkered")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var background: AnyShapeStyle {
        isFinished
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [GopherForgeTheme.gopherBlue, GopherForgeTheme.deepBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            : AnyShapeStyle(.background.secondary)
    }
}
