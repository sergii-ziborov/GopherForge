import SwiftUI

/// Authored diagrams and scenario scores stay available offline with the lesson.
struct ReadingDesignGuide: View {
    let guide: ReadingLesson.DesignGuide
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(guide.family, systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(guide.flow.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)").font(.caption.monospacedDigit().bold())
                            .foregroundStyle(tint)
                        Text(step).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    if index < guide.flow.count - 1 {
                        Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary)
                            .padding(.leading, 10).accessibilityHidden(true)
                    }
                }
            }
            Text("Implementation and operation cost: \(guide.cost)").font(.subheadline.weight(.semibold))
            if !guide.ratings.isEmpty {
                Text("Fit for the task").font(.subheadline.weight(.semibold))
                ForEach(guide.ratings, id: \.scenario) { rating in
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(rating.scenario)
                            Spacer(minLength: 12)
                            score(rating.score)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rating.scenario)
                            score(rating.score)
                        }
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(rating.scenario): \(rating.score) out of 5")
                }
                Text("Editorial suitability, not a speed or popularity ranking. 1 = usually avoid; 3 = useful with a specific need; 5 = a strong starting choice. Costs include implementation and operation. Styles can be combined.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            notes("Useful when", items: guide.strengths, symbol: "checkmark.circle")
            notes("Watch the tradeoff", items: guide.cautions, symbol: "exclamationmark.triangle")
        }
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reading.designGuide")
    }

    private func score(_ value: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Circle().fill(index <= value ? tint : tint.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
            Text("\(value)/5").monospacedDigit().padding(.leading, 4)
        }
        .fixedSize()
    }

    private func notes(_ title: String, items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Label { Text(item) } icon: {
                    Image(systemName: symbol).foregroundStyle(tint)
                }
                .font(.subheadline)
            }
        }
    }
}

struct ArchitectureComparisonView: View {
    @State private var scenario = "Domain-rich application"
    private let scenarios = ["Small tool or CLI", "Domain-rich application", "Independent distributed services"]

    private var readings: [ReadingLesson] {
        ReadingLessonCatalog.all.filter {
            $0.unitID == "architecture" && !($0.designGuide?.ratings.isEmpty ?? true)
        }.sorted {
            let left = rating($0), right = rating($1)
            return left == right ? $0.title < $1.title : left > right
        }
    }

    private func rating(_ reading: ReadingLesson) -> Int {
        reading.designGuide?.ratings.first { $0.scenario == scenario }?.score ?? 0
    }

    var body: some View {
        List {
            Section {
                Text("Choose the task before comparing styles. These are editorial suitability scores, not benchmarks or a universal ranking. DDD, CQRS and deployment styles describe different axes and can be combined.")
                    .font(.callout)
                Picker("Scenario", selection: $scenario) {
                    ForEach(scenarios, id: \.self) { Text($0) }
                }
                Text("1: usually avoid · 3: specific need · 5: strong starting choice")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Fit for this task") {
                ForEach(readings) { reading in
                    NavigationLink {
                        LessonDetailView(lesson: reading.lesson)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reading.title).font(.headline)
                            Text("\(rating(reading))/5 · Cost: \(reading.designGuide?.cost ?? "")")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(reading.objective).font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("architecture.compare.\(reading.id)")
                }
            }
        }
        .navigationTitle("Compare architectures")
        .navigationBarTitleDisplayMode(.inline)
    }
}
