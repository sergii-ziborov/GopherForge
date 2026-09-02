import SwiftUI

/// One scenario, in the order the lesson works: the question, your prediction,
/// the program, then what it actually did.
///
/// The takeaway is withheld until a run has happened. It is the answer, and an
/// answer sitting on screen beside the question is a lesson nobody has to think
/// their way through.
struct ConcurrencyScenarioView: View {
    let scenario: ConcurrencyLabScenario

    @State private var model: ConcurrencyLabModel

    init(scenario: ConcurrencyLabScenario) {
        self.scenario = scenario
        _model = State(initialValue: ConcurrencyLabModel(scenario: scenario))
    }

    private var hasRun: Bool { model.trace != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LessonSection(title: "The question", systemImage: "questionmark.circle") {
                    Text(scenario.question)
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }

                prediction

                LessonSection(title: "The program", systemImage: "chevron.left.forwardslash.chevron.right") {
                    CodeBlock(title: "", code: scenario.source)
                }

                if !model.canRun {
                    Label(model.toolchainDetail, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(GopherForgeTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let trace = model.trace {
                    ConcurrencyTimelineView(trace: trace)
                    ConcurrencyTraceView(trace: trace)
                }

                ForEach(model.diagnoses) { diagnosis in
                    DiagnosisCard(diagnosis: diagnosis)
                }

                if !model.programOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LessonSection(title: "What it printed", systemImage: "text.alignleft") {
                        CodeBlock(title: "", code: model.programOutput)
                    }
                }

                if let failureDetail = model.failureDetail {
                    Text(failureDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if hasRun {
                    takeaway
                }
            }
            .padding(16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.run() }
                } label: {
                    if model.isRunning {
                        ProgressView()
                    } else {
                        Label(hasRun ? "Run again" : "Run", systemImage: "play.fill")
                    }
                }
                .disabled(model.isRunning || !model.canRun)
                .accessibilityIdentifier(AccessibilityID.labRun)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(scenario.family.title, systemImage: scenario.family.systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)
            Text(scenario.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    GopherForgeTheme.gopherBlue.darkened(by: 0.20),
                    GopherForgeTheme.deepBlue.darkened(by: 0.25),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var prediction: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { model.hasPredicted },
            set: { model.hasPredicted = $0 }
        )) {
            Text(scenario.prediction)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label("Predict first, then open this", systemImage: "eye.slash")
                .font(.callout.weight(.medium))
        }
        .tint(GopherForgeTheme.accent)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier(AccessibilityID.labPrediction)
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What to take away", systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GopherForgeTheme.accent)
                .textCase(.uppercase)
            Text(scenario.takeaway)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GopherForgeTheme.accentWash(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A finding the lab drew out of the trace.
struct DiagnosisCard: View {
    let diagnosis: ConcurrencyDiagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(GopherForgeTheme.berry)
                Text(diagnosis.headline).font(.callout.weight(.medium))
            }
            Text(diagnosis.detail)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text(diagnosis.conceptTag)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GopherForgeTheme.berry.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
