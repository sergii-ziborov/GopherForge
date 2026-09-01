import SwiftUI

/// The result, and what to do about it.
///
/// A score alone is a grade. What is useful is which concepts went wrong and
/// where they will come back, so that is what this leads with when there are
/// any.
struct QuizSummaryView: View {
    let correct: Int
    let total: Int
    let passed: Bool
    let mistakenConcepts: [String]
    let onRestart: () -> Void

    private var fraction: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScoreRing(fraction: fraction, correct: correct, total: total, passed: passed)

                Text(headline)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !mistakenConcepts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming back in Review")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(mistakenConcepts, id: \.self) { tag in
                            Label(tag, systemImage: "arrow.trianglehead.counterclockwise")
                                .font(.caption.monospaced())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }

                Button("Try again", systemImage: "arrow.clockwise", action: onRestart)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.quizRestart)
            }
            .padding(20)
        }
        .accessibilityIdentifier(AccessibilityID.quizSummary)
    }

    private var headline: String {
        if correct == total { return "Every one." }
        return passed ? "Passed" : "Not yet"
    }

    private var message: String {
        if correct == total {
            return "Nothing to review from this one."
        }
        if passed {
            return "\(correct) of \(total). The ones you missed are queued for review."
        }
        return "\(correct) of \(total). Four in five passes — the misses are queued, "
            + "and the unit's lessons are the fastest way back."
    }
}

/// The score as a ring rather than a number alone: the shape says how it went
/// before the digits are read.
private struct ScoreRing: View {
    let fraction: Double
    let correct: Int
    let total: Int
    let passed: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(
                    LinearGradient(
                        colors: passed
                            ? [GopherForgeTheme.slate, GopherForgeTheme.accent]
                            : [GopherForgeTheme.warning, GopherForgeTheme.berry],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: fraction)

            VStack(spacing: 0) {
                Text("\(correct)").font(.largeTitle.weight(.bold).monospacedDigit())
                Text("of \(total)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 150, height: 150)
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(correct) of \(total) correct")
    }
}
