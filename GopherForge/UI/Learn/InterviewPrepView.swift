import SwiftUI

struct InterviewPrepView: View {
    @Environment(LearnProgress.self) private var progress
    @AppStorage("interview.preparation.selfAssessment.v1") private var assessment = "{}"
    private var marks: [String: String] { InterviewPresentation.marks(from: assessment) }
    private let bank = InterviewPrepBank.shared
    @State private var topic = ""
    @State private var level = 0
    @State private var query = ""
    @State private var openedQuestionID: String?
    @FocusState private var searchFocused: Bool

    private var understoodCount: Int { bank.questions.count { marks[$0.id] == "understood" } }
    private var revisitCount: Int { bank.questions.count { marks[$0.id] == "revisit" } }
    private var nextQuestion: InterviewPrepQuestion? {
        progress.resumeInterview ?? bank.questions.first { marks[$0.id] != "understood" } ?? bank.questions.first
    }
    private var isFiltering: Bool {
        !topic.isEmpty || level != 0 || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                hero
                tools
                filters
                if isFiltering {
                    let questions = bank.filtered(topic: topic, level: level, search: query)
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("\(questions.count) matching guides")
                        if questions.isEmpty {
                            ContentUnavailableView.search(text: query)
                        } else {
                            InterviewQuestionJourney(questions: questions, marks: marks)
                        }
                    }
                } else {
                    topicPath
                }
                Text("Read a question, explain it aloud, then compare the reasoning. All topics are open. Understood and Revisit are your study marks; course completion is tracked separately.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationDestination(item: $openedQuestionID) { id in
            if let question = bank.questions.first(where: { $0.id == id }) {
                InterviewPrepDetailView(question: question)
            }
        }
        .accessibilityIdentifier("interview.library")
    }

    private var hero: some View {
        let fraction = bank.questions.isEmpty ? 0 : Double(understoodCount) / Double(bank.questions.count)
        return LearningHeroCard(
            subtitle: "Go, for your next interview",
            title: "\(understoodCount) of \(bank.questions.count) guides",
            fraction: fraction,
            metrics: [
                LearningHeroMetric(symbol: "flag.checkered", value: "\(bank.topics.count)", label: "topics"),
                LearningHeroMetric(symbol: "arrow.counterclockwise", value: "\(revisitCount)", label: "to revisit"),
                LearningHeroMetric(symbol: "percent", value: "\(Int(fraction * 100))", label: "understood")
            ],
            actionTitle: progress.resumeInterview.map { "Continue: \($0.title)" } ?? "Start interview preparation",
            actionSymbol: "arrow.right",
            actionIdentifier: "interview.continue",
            onContinue: { openedQuestionID = nextQuestion?.id }
        )
    }

    private var tools: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 10)], spacing: 10) {
            NavigationLink {
                AlgorithmLibraryView()
            } label: {
                LearningToolCard(symbol: "point.3.connected.trianglepath.dotted", title: "Algorithms",
                                 detail: "\(bank.demonstrations.count) interactive walkthroughs", tint: GopherForgeTheme.berry)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interview.algorithms")

            NavigationLink {
                InterviewGuideCollectionView(title: "Revisit", summary: "Explain these concepts again, then update your study mark.", selection: .marked("revisit"))
            } label: {
                LearningToolCard(symbol: "figure.mind.and.body", title: "Revisit",
                                 detail: "\(revisitCount) guides to revisit", tint: GopherForgeTheme.aqua)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interview.revisit")

            NavigationLink {
                InterviewGuideCollectionView(title: "Understood", summary: "Return to the answers you have already worked through.", selection: .marked("understood"))
            } label: {
                LearningToolCard(symbol: "checkmark.circle", title: "Understood",
                                 detail: "\(understoodCount) guides marked", tint: Color(hex: 0xB07B00))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interview.understood")
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a question or concept", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("interview.search")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                Picker("Topic", selection: $topic) {
                    Text("All topics").tag("")
                    ForEach(bank.topics) { Text($0.title).tag($0.id) }
                }
                .accessibilityIdentifier("interview.topic")
                Spacer(minLength: 0)
                Picker("Difficulty", selection: $level) {
                    Text("All levels").tag(0)
                    ForEach(Array(bank.levels.enumerated()), id: \.offset) { i, name in
                        Text(name).tag(i + 1)
                    }
                }
                .accessibilityIdentifier("interview.level")
            }
            .pickerStyle(.menu)
            if isFiltering {
                Button("Reset filters") { topic = ""; level = 0; query = "" }
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("interview.resetFilters")
            }
        }
    }

    private var topicPath: some View {
        let items = bank.topics.map { topic in
            let questions = bank.questions.filter { $0.topic == topic.id }
            let done = questions.count { marks[$0.id] == "understood" }
            let style = InterviewPresentation.unitStyle(for: topic.id)
            return CoursePathItem(
                id: topic.id, title: topic.title, subtitle: topic.route,
                badge: "\(done) / \(questions.count) understood",
                symbol: CourseUnitStyle.symbol(for: style),
                state: done == questions.count ? .done : (topic.id == nextQuestion?.topic ? .next : .upcoming),
                tint: CourseUnitStyle.tint(for: style),
                accessibilityIdentifier: "interview.topic.\(topic.id)",
                accessibilityValue: "\(done) of \(questions.count) understood"
            )
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("The interview path")
            CourseJourneyView(items: items) { item in
                if let topic = bank.topics.first(where: { $0.id == item.id }) {
                    InterviewGuideCollectionView(title: topic.title, summary: topic.route, selection: .topic(topic.id))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
    }
}

private enum InterviewGuideSelection {
    case topic(String)
    case marked(String)
    case algorithms
}

/// Topic and study-mark screens use the same cards and rail as the course.
private struct InterviewGuideCollectionView: View {
    let title: String
    let summary: String
    let selection: InterviewGuideSelection
    @AppStorage("interview.preparation.selfAssessment.v1") private var assessment = "{}"
    private var marks: [String: String] { InterviewPresentation.marks(from: assessment) }
    private var questions: [InterviewPrepQuestion] {
        let bank = InterviewPrepBank.shared
        return bank.questions.filter { question in
            switch selection {
            case .topic(let id): question.topic == id
            case .marked(let mark): marks[question.id] == mark
            case .algorithms: bank.demonstrations.contains { $0.id == question.id }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.title2.bold())
                    Text("\(questions.count { marks[$0.id] == "understood" }) of \(questions.count) understood")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(GopherForgeTheme.accentWash(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                if questions.isEmpty {
                    ContentUnavailableView("No guides marked yet", systemImage: "bookmark",
                                           description: Text("Reveal a guide’s answer, then choose Revisit or Understood to save it here."))
                } else {
                    InterviewQuestionJourney(questions: questions, marks: marks)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct InterviewQuestionJourney: View {
    let questions: [InterviewPrepQuestion]
    let marks: [String: String]
    @Environment(LearnProgress.self) private var progress

    var body: some View {
        let bank = InterviewPrepBank.shared
        let items = questions.map { question in
            let mark = marks[question.id]
            let saved = question.id == progress.lastInterviewID
            let style = InterviewPresentation.unitStyle(for: question.topic)
            let status = mark == "understood" ? "Understood" : mark == "revisit" ? "Revisit" : "Not marked"
            return CoursePathItem(
                id: question.id, title: question.title,
                subtitle: "\(bank.levels[question.level - 1]) · \(bank.topics.first { $0.id == question.topic }?.title ?? question.topic)",
                badge: saved ? "Saved place · \(status)" : status,
                symbol: mark == "revisit" ? "arrow.counterclockwise" : "questionmark",
                state: mark == "understood" ? .done : (saved ? .next : .upcoming),
                tint: CourseUnitStyle.tint(for: style),
                accessibilityIdentifier: "interview.question.\(question.id)",
                accessibilityValue: saved ? "Your saved place. \(status)" : status
            )
        }
        CourseJourneyView(items: items) { item in
            if let question = questions.first(where: { $0.id == item.id }) {
                InterviewPrepDetailView(question: question)
            }
        }
    }
}

private enum InterviewPresentation {
    static func marks(from assessment: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(assessment.utf8))) ?? [:]
    }

    static func unitStyle(for topic: String) -> String {
        switch topic {
        case "language": "core"
        case "algorithms": "collections"
        case "design": "architecture"
        case "http": "services"
        case "testing": "clean-code"
        case "mongodb", "redis": "datastores"
        case "platform": "operations"
        case "ai": "patterns-go"
        default: topic
        }
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
        InterviewGuideCollectionView(
            title: "Algorithms",
            summary: "Trace an invariant, compare boundary cases, then explain the complexity.",
            selection: .algorithms
        )
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
