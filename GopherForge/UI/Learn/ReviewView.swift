import SwiftUI

/// Match terms and meanings from lessons already finished.
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LearnProgress.self) private var progress
    @State private var boards: [MatchingDrill] = []
    @State private var index = 0
    @State private var canAdvance = false
    @State private var hasLoaded = false
    @State private var loadedCompletion: Set<String>?
    @State private var loadedConcepts: Set<String> = []
    @State private var completionGeneration = UUID()

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
            await progress.refresh()
            loadBoards()
            hasLoaded = true
        }
        .onChange(of: progress.completed) { _, _ in loadBoards() }
        .onChange(of: progress.confirmedConcepts) { _, _ in loadBoards() }
    }

    private var empty: some View {
        ContentUnavailableView(
            "Nothing to match yet",
            systemImage: "link",
            description: Text(
                "Learn enough concepts to fill at least three matching pairs. "
                    + "Finish lessons or answer knowledge-check questions correctly; Review only uses what you have learned."
            )
        )
        .accessibilityIdentifier(AccessibilityID.reviewEmpty)
    }

    private var session: some View {
        MatchingDrillView(drill: boards[index], onRestart: {
            completionGeneration = UUID()
            canAdvance = false
        }, onFinish: finished)
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
                        Text("Session complete. Wrong connections are saved in Fix mistakes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button { dismiss() } label: {
                            Text("Finish review")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(AccessibilityID.reviewDone)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
    }

    private func finished(_ result: MatchingDrillResult) {
        let generation = completionGeneration
        Task {
            await progress.record(result)
            guard generation == completionGeneration else { return }
            canAdvance = true
        }
    }

    private func loadBoards() {
        guard loadedCompletion != progress.completed || loadedConcepts != progress.confirmedConcepts else { return }
        loadedCompletion = progress.completed
        loadedConcepts = progress.confirmedConcepts
        boards = ReviewMatchCatalog.unlocked(
            completed: progress.completed, confirmedConcepts: progress.confirmedConcepts,
            shuffle: { $0.shuffled() }
        )
        index = 0
        completionGeneration = UUID()
        canAdvance = false
    }
}
