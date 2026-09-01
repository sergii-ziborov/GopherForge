import SwiftUI

/// The card at the top of Learn: how far through the course you are, and one
/// button that goes where you left off.
///
/// Gopher Blue as a fill with white on it, which is the one place the bright
/// blue is legible — as text it sits at roughly 2.4:1 on white and fails.
struct CourseHeroCard: View {
    let doneCount: Int
    let totalCount: Int
    let unitCount: Int
    let verifiedCount: Int
    let isFinished: Bool
    let onContinue: () -> Void

    private var fraction: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    private var actionTitle: String {
        if isFinished { return "Start the course again" }
        return doneCount == 0 ? "Start the course" : "Continue where you left off"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Go, for people who already program")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(doneCount) of \(totalCount) lessons")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }

            ProgressView(value: fraction)
                .tint(.white)
                .background(.white.opacity(0.25), in: Capsule())

            HStack(spacing: 10) {
                HeroMetric(symbol: "flag.checkered", value: "\(unitCount)", label: "units")
                HeroMetric(symbol: "checkmark.seal.fill", value: "\(verifiedCount)", label: "compiler-passed")
                HeroMetric(symbol: "percent", value: "\(Int(fraction * 100))", label: "done")
            }

            Button(action: onContinue) {
                HStack(spacing: 8) {
                    Image(systemName: isFinished ? "arrow.counterclockwise" : "arrow.right")
                    Text(actionTitle).font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(GopherForgeTheme.deepBlue)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.courseContinue)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [GopherForgeTheme.gopherBlue, GopherForgeTheme.deepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: GopherForgeTheme.gopherBlue.opacity(0.28), radius: 16, y: 8)
    }
}

private struct HeroMetric: View {
    let symbol: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption2)
                Text(value).font(.footnote.bold().monospacedDigit())
            }
            Text(label).font(.system(size: 9))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// Everything that hangs off the course: the queue of what you got wrong, the
/// drills, the lab, the examples and the badges.
struct LearnToolRow: View {
    let practiceUnlocked: Int
    let practiceTotal: Int
    let badgesEarned: Int
    let badgesTotal: Int
    let onQuizFinished: (QuizResult) -> Void
    let onDrillFinished: (MatchingDrillResult) -> Void
    let completed: Set<String>
    let stats: LearnerStats

    private let columns = [GridItem(.adaptive(minimum: 172), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            NavigationLink {
                ReviewView()
            } label: {
                ToolCard(
                    symbol: "arrow.trianglehead.counterclockwise",
                    title: "Review",
                    detail: "Your mistakes",
                    tint: GopherForgeTheme.berry
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.reviewEntry)

            NavigationLink {
                PracticeHomeView(
                    completed: completed,
                    onQuizFinished: onQuizFinished,
                    onDrillFinished: onDrillFinished
                )
            } label: {
                ToolCard(
                    symbol: "figure.mind.and.body",
                    title: "Practice",
                    detail: "\(practiceUnlocked) / \(practiceTotal) open",
                    tint: GopherForgeTheme.aqua
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.practiceEntry)

            NavigationLink {
                ConcurrencyLabView()
            } label: {
                ToolCard(
                    symbol: "arrow.triangle.branch",
                    title: "Concurrency Lab",
                    detail: "Goroutines, live",
                    tint: GopherForgeTheme.sky
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.labEntry)

            NavigationLink {
                ExampleLibraryView()
            } label: {
                ToolCard(
                    symbol: "books.vertical",
                    title: "Examples",
                    detail: "Programs that run",
                    tint: Color(hex: 0x4E8F3E)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.examplesEntry)

            NavigationLink {
                AchievementsView(stats: stats)
            } label: {
                ToolCard(
                    symbol: "rosette",
                    title: "Achievements",
                    detail: "\(badgesEarned) / \(badgesTotal) earned",
                    tint: Color(hex: 0xB07B00)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.achievementsEntry)
        }
    }
}

private struct ToolCard: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}
