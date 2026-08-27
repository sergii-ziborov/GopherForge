import SwiftUI

/// What the learner has earned, and what is one step away.
///
/// Every badge shows its own counter, unlocked or not. A locked badge with a
/// hidden requirement is a slot machine; a locked badge that says "3 / 5" is
/// something to go and finish.
struct AchievementsView: View {
    let stats: LearnerStats

    private var ordered: [Achievement] {
        AchievementCatalog.ordered(by: stats)
    }

    private var unlockedCount: Int {
        AchievementCatalog.unlocked(by: stats).count
    }

    var body: some View {
        List {
            Section {
                ForEach(ordered) { achievement in
                    AchievementRow(achievement: achievement, stats: stats)
                        .accessibilityIdentifier("achievement.\(achievement.id)")
                }
            } header: {
                Text("\(unlockedCount) of \(AchievementCatalog.all.count) earned")
            } footer: {
                Text("Every badge is earned by compiling, running, testing or fixing "
                    + "something. None of them are for opening a screen.")
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let stats: LearnerStats

    private var isUnlocked: Bool { achievement.isUnlocked(by: stats) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: achievement.symbol)
                .font(.title3)
                .foregroundStyle(isUnlocked ? GopherForgeTheme.anvil : Color.secondary)
                .frame(width: 30, alignment: .center)
                .opacity(isUnlocked ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.body.weight(isUnlocked ? .semibold : .regular))
                Text(achievement.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !isUnlocked {
                    ProgressView(value: achievement.fraction(of: stats))
                        .progressViewStyle(.linear)
                }
            }

            Spacer(minLength: 8)

            Text(achievement.progressLabel(for: stats))
                .font(.caption2.monospaced())
                .foregroundStyle(isUnlocked ? Color.green : Color.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(achievement.title). \(achievement.detail). "
                + (isUnlocked ? "Earned." : "\(achievement.progressLabel(for: stats)).")
        )
    }
}
