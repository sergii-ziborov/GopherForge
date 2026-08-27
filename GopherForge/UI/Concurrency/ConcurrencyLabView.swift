import SwiftUI

/// The lab: pick a scenario, predict, run, then read what happened.
struct ConcurrencyLabView: View {
    @State private var model = ConcurrencyLabModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                scenarioPicker

                Text(model.scenario.question)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if !model.canRun {
                    Label(model.toolchainDetail, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                predictionSection

                CodeBlock(title: "The program", code: model.scenario.source)

                if let trace = model.trace {
                    ConcurrencyTraceView(trace: trace)
                }

                ForEach(model.diagnoses) { diagnosis in
                    DiagnosisCard(diagnosis: diagnosis)
                }

                if !model.programOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CodeBlock(title: "Program output", code: model.programOutput)
                }

                if let failureDetail = model.failureDetail {
                    Text(failureDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Concurrency Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.run() }
                } label: {
                    if model.isRunning {
                        ProgressView()
                    } else {
                        Label("Run", systemImage: "play.fill")
                    }
                }
                .disabled(model.isRunning || !model.canRun)
                .accessibilityIdentifier(AccessibilityID.labRun)
            }
        }
    }

    private var scenarioPicker: some View {
        Picker("Scenario", selection: Binding(
            get: { model.scenario.id },
            set: { id in
                if let found = ConcurrencyLabScenario.all.first(where: { $0.id == id }) {
                    model.select(found)
                }
            }
        )) {
            ForEach(ConcurrencyLabScenario.all) { scenario in
                Text(scenario.title).tag(scenario.id)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(AccessibilityID.labScenarioPicker)
    }

    private var predictionSection: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { model.hasPredicted },
            set: { model.hasPredicted = $0 }
        )) {
            Text(model.scenario.prediction)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Predict first, then open this")
                .font(.callout.weight(.medium))
        }
        .accessibilityIdentifier(AccessibilityID.labPrediction)
    }
}

private struct DiagnosisCard: View {
    let diagnosis: ConcurrencyDiagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(GopherForgeTheme.ember)
                Text(diagnosis.headline).font(.callout.weight(.medium))
            }
            Text(diagnosis.detail)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text(diagnosis.conceptTag)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
