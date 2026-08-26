import SwiftUI

/// go test results, one row per case.
struct TestResultListView: View {
    let tests: [GoTestResult]

    var body: some View {
        if tests.isEmpty {
            EmptyDockMessage(
                systemImage: "checkmark.diamond",
                title: "No tests have run",
                message: "Add a _test.go file and run Test."
            )
        } else {
            List {
                Section {
                    ForEach(tests) { test in
                        row(for: test)
                    }
                } header: {
                    Text("\(tests.passedCount) passed · \(tests.failedCount) failed")
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(for test: GoTestResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon(for: test.outcome))
                    .foregroundStyle(color(for: test.outcome))
                Text(test.name).font(.callout.monospaced())
                Spacer()
                if let elapsed = test.elapsedSeconds {
                    Text(String(format: "%.2fs", elapsed))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !test.output.isEmpty {
                Text(test.output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 2)
    }

    private func icon(for outcome: GoTestResult.Outcome) -> String {
        switch outcome {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    private func color(for outcome: GoTestResult.Outcome) -> Color {
        switch outcome {
        case .passed: .green
        case .failed: .red
        case .skipped: .secondary
        }
    }
}
