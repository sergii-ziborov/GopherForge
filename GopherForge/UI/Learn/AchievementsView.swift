import SwiftUI

/// What the learner has earned, and what is one step away.
///
/// Every badge shows its own counter, unlocked or not. A locked badge with a
/// hidden requirement is a slot machine; a locked badge that says "3 / 5" is
/// something to go and finish.
struct AchievementsView: View {
    let stats: LearnerStats
    @State private var gameCenter = GameCenterService()

    private var ordered: [Achievement] {
        AchievementCatalog.ordered(by: stats)
    }

    private var earnedLevels: Int {
        AchievementCatalog.earnedLevelCount(by: stats)
    }

    var body: some View {
        List {
            Section {
                GameCenterRow(service: gameCenter, stats: stats)
            } header: {
                Text("Game Center")
            } footer: {
                Text("Every badge is earned and kept on this device whether or not you "
                    + "sign in. Game Center is a mirror, not the record.")
            }

            Section {
                ForEach(ordered) { achievement in
                    AchievementRow(achievement: achievement, stats: stats)
                        .accessibilityIdentifier("achievement.\(achievement.id)")
                }
            } header: {
                Text("\(earnedLevels) of \(AchievementCatalog.totalLevelCount) levels earned")
            } footer: {
                Text("Every badge is earned by compiling, running, testing or fixing "
                    + "something. None of them are for opening a screen.")
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        // No automatic sign-in. Authenticating presents Apple's own sheet over
        // whatever the person opened, and being asked to sign in to something
        // for looking at a list is exactly the kind of thing that makes people
        // close an app.
        .task { await gameCenter.reportIfAlreadySignedIn(stats) }
    }
}

/// Sign-in state, and the way into the dashboard.
private struct GameCenterRow: View {
    let service: GameCenterService
    let stats: LearnerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: service.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(service.isSignedIn ? Color.green : Color.secondary)
                Text(service.statusDescription)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier(AccessibilityID.gameCenterStatus)

            if service.isSignedIn {
                Button("Open Game Center", systemImage: "trophy") {
                    service.showDashboard()
                }
                .font(.footnote)
                .accessibilityIdentifier(AccessibilityID.gameCenterDashboard)
            } else {
                Button("Connect Game Center", systemImage: "person.badge.plus") {
                    Task {
                        await service.authenticate()
                        await service.report(stats)
                    }
                }
                .font(.footnote)
                .accessibilityIdentifier(AccessibilityID.gameCenterConnect)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let stats: LearnerStats

    private var current: AchievementLevel? { achievement.currentLevel(for: stats) }
    private var next: AchievementLevel? { achievement.nextLevel(for: stats) }
    private var isUnlocked: Bool { current != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: achievement.symbol)
                    .font(.title3)
                    .foregroundStyle(current.map(Self.colour) ?? Color.secondary)
                    .frame(width: 30, alignment: .center)
                    .opacity(isUnlocked ? 1 : 0.45)

                VStack(alignment: .leading, spacing: 3) {
                    // The level's own name leads when there is one: "Anvil
                    // warmed" is what was earned, and the badge's name is only
                    // the family it belongs to.
                    Text(current?.title ?? achievement.title)
                        .font(.body.weight(isUnlocked ? .semibold : .regular))
                    Text(achievement.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    if let current {
                        RankChip(rank: current.rank)
                    }
                    Text(achievement.progressLabel(for: stats))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            LevelTrack(achievement: achievement, stats: stats)

            if let next {
                Text("\(next.target - achievement.progress(in: stats)) more "
                    + "\(achievement.progressUnit) for \(next.rank.title): \(next.title)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Every level earned.")
                    .font(.caption2)
                    .foregroundStyle(GopherForgeTheme.accent)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.label(for: achievement, stats: stats))
    }

    static func colour(for level: AchievementLevel) -> Color {
        switch level.rank {
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.20)
        case .silver: Color(red: 0.62, green: 0.66, blue: 0.70)
        case .gold: Color(red: 0.85, green: 0.68, blue: 0.13)
        case .platinum: GopherForgeTheme.accent
        }
    }

    private static func label(for achievement: Achievement, stats: LearnerStats) -> String {
        let earned = achievement.currentLevel(for: stats)
        let base = "\(achievement.title). \(achievement.detail)."
        guard let earned else {
            return base + " Not started. \(achievement.progressLabel(for: stats))."
        }
        return base + " \(earned.rank.title): \(earned.title). "
            + "\(achievement.progressLabel(for: stats))."
    }
}

/// The rank a badge currently sits at.
private struct RankChip: View {
    let rank: AchievementRank

    var body: some View {
        Label(rank.title, systemImage: rank.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                AchievementRow.colour(for: AchievementLevel(rank: rank, target: 0, title: ""))
                    .opacity(0.16),
                in: Capsule()
            )
            .foregroundStyle(
                AchievementRow.colour(for: AchievementLevel(rank: rank, target: 0, title: ""))
            )
    }
}

/// All four rungs at once: the ones behind, the one being climbed, the ones
/// ahead. A single bar would hide how much of the badge is left.
private struct LevelTrack: View {
    let achievement: Achievement
    let stats: LearnerStats

    var body: some View {
        HStack(spacing: 4) {
            ForEach(achievement.levels, id: \.rank) { level in
                let earned = achievement.progress(in: stats) >= level.target
                let isCurrent = achievement.nextLevel(for: stats)?.rank == level.rank

                Capsule()
                    .fill(
                        earned
                            ? AnyShapeStyle(AchievementRow.colour(for: level))
                            : AnyShapeStyle(Color.secondary.opacity(0.18))
                    )
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        // The rung being climbed fills as far as it has come,
                        // so the track shows position rather than only count.
                        if isCurrent {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(AchievementRow.colour(for: level).opacity(0.55))
                                    .frame(width: proxy.size.width * achievement.fraction(of: stats))
                            }
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}
