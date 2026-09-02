import SwiftUI

/// The bug hunt: a short program, one thing wrong, tap the line.
///
/// A guess is committed on the tap. There is no confirm step, because the
/// hesitation a confirm invites is the thing the game is trying to remove —
/// code review is reading and noticing, at speed.
struct SpotTheBugView: View {
    @State private var session: SpotTheBugSession
    let onFinish: (MatchingDrillResult) -> Void

    init(rounds: [SpotTheBugRound], onFinish: @escaping (MatchingDrillResult) -> Void) {
        _session = State(initialValue: SpotTheBugSession(rounds: rounds))
        self.onFinish = onFinish
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                progress

                if let round = session.round {
                    brief(round)
                    program(round)
                    if let answer = session.currentAnswer {
                        verdict(round, answer: answer)
                    } else {
                        Text("Tap the line that is wrong.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    summary
                }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Spot the bug")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.spotTheBugBoard)
        .onChange(of: session.isFinished) { _, finished in
            if finished { onFinish(session.result) }
        }
    }

    // MARK: - Pieces

    private var progress: some View {
        HStack(spacing: 10) {
            Text("\(min(session.index + 1, session.rounds.count)) of \(session.rounds.count)")
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(.secondary)
            ProgressView(
                value: Double(session.answers.count),
                total: Double(max(session.rounds.count, 1))
            )
            .tint(GopherForgeTheme.accent)
            Text("\(session.correctCount) found")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier(AccessibilityID.spotTheBugProgress)
    }

    private func brief(_ round: SpotTheBugRound) -> some View {
        Text(round.brief)
            .font(.callout.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func program(_ round: SpotTheBugRound) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(round.lines.enumerated()), id: \.offset) { index, line in
                Button {
                    session.choose(line: index)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 22, alignment: .trailing)
                        GoCodeText(code: line.isEmpty ? " " : line, fileKind: .go)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: index, in: round))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(session.hasAnswered)
                .accessibilityIdentifier(AccessibilityID.spotTheBugLine(index))
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// After the guess the faulty line is always marked, and a wrong guess is
    /// marked too — seeing both is what makes the miss legible.
    private func background(for index: Int, in round: SpotTheBugRound) -> Color {
        guard let answer = session.currentAnswer else { return .clear }
        if index == round.faultyLine { return Color.green.opacity(0.22) }
        if index == answer.chosenLine { return GopherForgeTheme.berry.opacity(0.20) }
        return .clear
    }

    private func verdict(_ round: SpotTheBugRound, answer: SpotTheBugSession.Answer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                answer.isCorrect ? "Found it" : "That was line \(answer.chosenLine + 1)",
                systemImage: answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(answer.isCorrect ? Color.green : GopherForgeTheme.berry)

            Text(round.explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Text(round.conceptTag)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)

            Button {
                session.advance()
            } label: {
                Text(session.index + 1 == session.rounds.count ? "Finish" : "Next program")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.spotTheBugContinue)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (answer.isCorrect ? Color.green : GopherForgeTheme.berry).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(session.correctCount) of \(session.rounds.count) found")
                .font(.title3.weight(.semibold))

            if session.missedConceptTags.isEmpty {
                Text("Every one. The misses would have gone to the review queue; there were none.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("What the misses were about — these go to the review queue:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ForEach(Array(Set(session.missedConceptTags)).sorted(), id: \.self) { tag in
                    Text(tag)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GopherForgeTheme.berry.opacity(0.12), in: Capsule())
                        .foregroundStyle(GopherForgeTheme.berry)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(AccessibilityID.spotTheBugSummary)
    }
}
