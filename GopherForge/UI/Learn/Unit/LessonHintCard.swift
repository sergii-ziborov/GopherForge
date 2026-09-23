import SwiftUI

/// Hints for reading and prediction tasks, which have no Check result capable
/// of opening the failure sheet. There is intentionally no Realize action here.
struct LessonReferenceHintCard: View {
    let hint: LessonHint
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hint", systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)

            Text(hint.hint)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.lessonHint)

            Text(hint.nuance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.lessonNuance)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Help offered only after Check has failed.
///
/// Keeping this in a sheet makes the sequence honest: first make an attempt,
/// then inspect the concrete failures, then choose between another edit and a
/// verified answer. The old always-visible card revealed the escape hatch
/// before there was anything to escape from.
struct LessonFailureSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: CompilationResult
    let hint: LessonHint
    let canRealize: Bool
    let tint: Color
    let onRealize: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(result.detail, systemImage: "xmark.octagon.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    failureDetails

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Hint", systemImage: "lightbulb")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                            .textCase(.uppercase)

                        Text(hint.hint)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(AccessibilityID.lessonHint)

                        Text(hint.nuance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(AccessibilityID.lessonNuance)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        .background.secondary,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                    if canRealize {
                        Button {
                            dismiss()
                            onRealize()
                        } label: {
                            Label("Realize and check", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(AccessibilityID.lessonRealize)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Check did not pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep editing") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var failureDetails: some View {
        let failed = result.tests.filter { $0.outcome == .failed }
        if !failed.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("What failed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(failed) { test in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(test.name).font(.caption.monospaced().weight(.semibold))
                        Text(test.output.isEmpty ? "No additional message." : test.output)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        } else if !result.diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("What failed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(result.diagnostics) { diagnostic in
                    Text(diagnostic.rendered)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        } else if !result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(result.stderr)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        } else {
            Text("The check stopped without additional output. Try Realize and check; if it also fails, this result will stay visible.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
