import SwiftUI

struct InterviewPrepView: View {
    @Environment(LearnProgress.self) private var progress
    @AppStorage("interview.preparation.selfAssessment.v1") private var assessment = "{}"
    private var marks: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(assessment.utf8))) ?? [:]
    }
    private let bank = InterviewPrepBank.shared
    @State private var topic = ""
    @State private var level = 0
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Topic", selection: $topic) {
                    Text("All topics").tag("")
                    ForEach(bank.topics) { Text($0.title).tag($0.id) }
                }
                .accessibilityIdentifier("interview.topic")
                Picker("Difficulty", selection: $level) {
                    Text("All levels").tag(0)
                    ForEach(Array(bank.levels.enumerated()), id: \.offset) { i, name in
                        Text(name).tag(i + 1)
                    }
                }
                .accessibilityIdentifier("interview.level")
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            List {
                Section {
                    if let resume = progress.resumeInterview {
                        NavigationLink {
                            InterviewPrepDetailView(question: resume)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Continue where you left off").font(.caption).foregroundStyle(.secondary)
                                    Text(resume.title).font(.headline)
                                }
                            } icon: { Image(systemName: "arrow.right.circle.fill") }
                        }
                        .accessibilityIdentifier("interview.continue")
                    }
                    Text("\(bank.questions.count { marks[$0.id] == "understood" }) of \(bank.questions.count) understood · \(bank.questions.count { marks[$0.id] == "revisit" }) to revisit")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Prepare, explain, then test")
                        .font(.title2.bold())
                    Text("\(bank.questions.count) worked interview guides · \(bank.topics.count) topics · Junior to Staff / expert. No gates. Read a question, explain it aloud, then compare the reasoning. Self-assessment is separate from course completion.")
                        .font(.callout).foregroundStyle(.secondary)
                    NavigationLink("Algorithm demonstrations · 8 interactive walkthroughs") {
                        AlgorithmLibraryView()
                    }
                    .accessibilityIdentifier("interview.algorithms")
                }
                let questions = bank.filtered(topic: topic, level: level, search: query)
                if questions.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(questions) { question in
                        NavigationLink {
                            InterviewPrepDetailView(question: question)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(question.title).font(.headline)
                                if question.id == progress.lastInterviewID {
                                    Label("Your saved place", systemImage: "bookmark.fill").font(.caption).foregroundStyle(GopherForgeTheme.accent)
                                }
                                if let mark = marks[question.id] {
                                    Label(mark == "understood" ? "Understood" : "Revisit", systemImage: mark == "understood" ? "checkmark.circle" : "arrow.counterclockwise").font(.caption).foregroundStyle(.secondary)
                                }
                                Text("\(bank.levels[question.level - 1]) · \(bank.topics.first { $0.id == question.topic }?.title ?? question.topic)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 5)
                        }
                        .accessibilityIdentifier("interview.question.\(question.id)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .transparentBottomScrollEdge()
        }
        .searchable(text: $query, prompt: "Find a question or concept")
        .accessibilityIdentifier("interview.library")
    }
}

struct InterviewPrepDetailView: View {
    let question: InterviewPrepQuestion
    @Environment(LearnProgress.self) private var progress
    @State private var revealed = false
    @AppStorage("interview.preparation.selfAssessment.v1") private var assessment = "{}"
    private var marks: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(assessment.utf8))) ?? [:]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(InterviewPrepBank.shared.levels[question.level - 1]).font(.caption.bold()).foregroundStyle(.secondary)
                Text(question.title).font(.largeTitle.bold())
                Text(question.prompt).font(.title3)
                if let demo = InterviewPrepBank.shared.demonstrations.first(where: { $0.id == question.id }) {
                    AlgorithmTraceView(demonstration: demo)
                }
                if !question.code.isEmpty { CodeBlock(title: "Example · fragment unless a complete program is shown", code: question.code) }
                if revealed {
                    section("A strong answer", text: question.answerPoints.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n"))
                    section("Common trap", text: question.trap)
                    if !question.complexity.isEmpty { section("Complexity and use", text: question.complexity) }
                } else {
                    Button("Explain it aloud, then reveal the answer") { revealed = true }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("interview.prep.reveal")
                }
                section("Try it", text: question.exercise)
                DisclosureGroup("Worked solution") { Text(LearningProse.inline(question.solution)).padding(.vertical, 8) }
                    .accessibilityIdentifier("interview.prep.solution")
                section("Follow-up", text: question.followUp)
                if revealed {
                    Text("Self-assessment · \(marks[question.id] ?? "not marked")").font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("interview.prep.status")
                    HStack {
                        Button("Revisit") { mark("revisit") }.buttonStyle(.bordered)
                        Button("Understood") { mark("understood") }.buttonStyle(.borderedProminent)
                        Button("Clear") { mark(nil) }.buttonStyle(.bordered)
                    }
                    Text("A personal study mark, not an interview score or compiler pass.").font(.caption).foregroundStyle(.secondary)
                }
                section("Primary references", text: "Documentation checked \(InterviewPrepBank.shared.reviewedOn). Product interfaces and runtime behavior may change; use the docs for your pinned version.")
                ForEach(question.references, id: \.self) { link in
                    if let url = URL(string: link) { Link(link, destination: url).font(.caption).lineLimit(3) }
                }
            }
            .padding(20).padding(.bottom, 100).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .transparentBottomScrollEdge()
        .onAppear { progress.visitInterview(question.id) }
        .navigationTitle("Interview")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(GopherForgeTheme.accent)
            Text(LearningProse.inline(text)).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func mark(_ value: String?) {
        var updated = marks
        updated[question.id] = value
        if let data = try? JSONEncoder().encode(updated), let text = String(data: data, encoding: .utf8) { assessment = text }
    }
}
struct AlgorithmLibraryView: View {
    var body: some View {
        List(InterviewPrepBank.shared.questions.filter { question in
            InterviewPrepBank.shared.demonstrations.contains { $0.id == question.id }
        }) { question in
            NavigationLink(question.title) { InterviewPrepDetailView(question: question) }
        }.navigationTitle("Algorithms")
    }
}
struct AlgorithmTraceView: View {
    let demonstration: AlgorithmDemonstration
    @State private var selected = 0
    @State private var index = 0
    private var scenario: AlgorithmCase { demonstration.cases[selected] }
    private var step: AlgorithmStep { scenario.steps[min(index, scenario.steps.count - 1)] }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Algorithm laboratory", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
            Picker("Input scenario", selection: $selected) {
                ForEach(demonstration.cases.indices, id: \.self) { Text(demonstration.cases[$0].name).tag($0) }
            }.pickerStyle(.menu).onChange(of: selected) { _, _ in index = 0 }
            Text(scenario.input).font(.caption.monospaced()).textSelection(.enabled)
            Text("Step \(index + 1) / \(scenario.steps.count) · \(step.title)").font(.headline)
                .accessibilityIdentifier("algorithm.step")
            ForEach(Array(step.rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.label).font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            if row.values.isEmpty { Text("∅").foregroundStyle(.secondary) }
                            ForEach(row.values.indices, id: \.self) { i in
                                VStack(spacing: 4) {
                                    Text(row.values[i]).font(.body.monospaced().bold())
                                    Text("\(i)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                                .padding(10).frame(minWidth: 42)
                                .background(row.active.contains(i) ? GopherForgeTheme.accentWash(0.25) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityLabel("\(row.label), index \(i), value \(row.values[i])\(row.active.contains(i) ? ", active" : "")")
                            }
                        }
                    }
                }
            }
            Text(step.note).font(.callout)
            HStack {
                Button("Reset") { index = 0 }.disabled(index == 0)
                Spacer()
                Button("Back") { index -= 1 }.disabled(index == 0)
                Button("Next step") { index += 1 }.disabled(index + 1 >= scenario.steps.count)
                    .accessibilityIdentifier("algorithm.next")
            }.buttonStyle(.bordered)
            if index + 1 == scenario.steps.count { Text("Result: \(scenario.result)").font(.headline).accessibilityIdentifier("algorithm.result") }
            Text("Computed trace for these inputs. Indexes under cells identify positions; highlighted cells are active. Change the scenario to compare a boundary case.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}
