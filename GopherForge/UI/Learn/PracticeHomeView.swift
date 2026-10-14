import SwiftUI

/// Actual mistakes, with a separate knowledge check when there are none.
/// There are no lesson-count locks and no self-reported challenge passes.
struct PracticeHomeView: View {
    @Environment(LearnProgress.self) private var progress
    @State private var questions: [MistakeReviewQuestion] = []
    @State private var isCorrecting = true
    @State private var showsSession = false

    private var pending: [MistakeReviewQuestion] {
        MistakeReviewCatalog.pendingQuestions(
            concepts: progress.pendingMistakeConcepts, history: progress.correctionAttempts
        )
    }

    private var answeredCount: Int {
        Set(progress.correctionAttempts.filter { $0.succeeded }.compactMap(\.questionID)).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(pending.isEmpty ? "No mistakes to revisit" : "\(pending.count) concepts to revisit",
                          systemImage: pending.isEmpty ? "checkmark.circle" : "arrow.counterclockwise")
                        .font(.title3.bold())
                    Text("Mistakes from your code, quizzes and matching boards appear here. Answer correctly to clear a concept; a new mistake brings it back.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !pending.isEmpty {
                        Button("Work through mistakes", systemImage: "arrow.right") {
                            open(pending, correcting: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("mistakes.start")
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GopherForgeTheme.aqua.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("mistakes.summary")

                ForEach(GoCourseCatalog.units) { unit in
                    let count = pending.count { $0.unitID == unit.id }
                    if count > 0 {
                        Button {
                            open(pending.filter { $0.unitID == unit.id }, correcting: true)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: CourseUnitStyle.symbol(for: unit.id))
                                    .foregroundStyle(CourseUnitStyle.tint(for: unit.id))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(unit.title).font(.callout.bold())
                                    Text("\(count) concept\(count == 1 ? "" : "s") to fix")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mistakes.unit.\(unit.id)")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Check what you know").font(.headline)
                    Text("One question, three answers. Start with Go core or revisit concepts from completed lessons.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if answeredCount > 0 {
                        Text("\(answeredCount) questions answered correctly")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("mistakes.answeredCount")
                    }
                    Button("Start a knowledge check", systemImage: "questionmark.circle") {
                        open(MistakeReviewCatalog.practiceQuestions(
                            completed: progress.completed, history: progress.correctionAttempts
                        ), correcting: false)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("practice.start")
                }
            }
            .padding(18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Work on mistakes")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsSession) {
            MistakeReviewView(questions: questions, correcting: isCorrecting)
        }
        .task { await progress.refresh() }
    }

    private func open(_ snapshot: [MistakeReviewQuestion], correcting: Bool) {
        guard !snapshot.isEmpty else { return }
        questions = snapshot
        isCorrecting = correcting
        showsSession = true
    }
}
