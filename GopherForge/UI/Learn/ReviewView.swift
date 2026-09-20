import SwiftUI

/// A short run of match boards, earned by finishing lessons.
///
/// Review used to be a list of lessons the scheduler thought were weak. That
/// is a queue, not practice. This is the opposite: five terms on the left,
/// five meanings on the right, up to five boards, and only pairs from lessons
/// already done — so the board never asks for something the course has not
/// taught yet.
struct ReviewView: View {
    @Environment(LearnProgress.self) private var progress
    @State private var boards: [MatchingDrill] = []
    @State private var index = 0
    @State private var canAdvance = false
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if boards.isEmpty, hasLoaded {
                empty
            } else if !boards.isEmpty {
                session
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            boards = ReviewMatchCatalog.unlocked(completed: progress.completed)
            hasLoaded = true
        }
    }

    private var empty: some View {
        ContentUnavailableView(
            "Nothing to match yet",
            systemImage: "link",
            description: Text(
                "Finish five lessons and Review deals a board of five pairs "
                    + "from what you already know. Achievements stay on Learn."
            )
        )
        .accessibilityIdentifier(AccessibilityID.reviewEmpty)
    }

    private var session: some View {
        MatchingDrillView(drill: boards[index], onFinish: finished)
            .id(boards[index].id)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Text("Match \(index + 1) of \(boards.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.reviewProgress)

                    if canAdvance, index + 1 < boards.count {
                        Button {
                            index += 1
                            canAdvance = false
                        } label: {
                            Text("Next match")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(AccessibilityID.reviewNext)
                    } else if canAdvance {
                        Text("Session complete. Those wrong connections come back here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
    }

    private func finished(_ result: MatchingDrillResult) {
        canAdvance = true
        Task { await progress.record(result) }
    }
}
