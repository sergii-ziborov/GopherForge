import SwiftUI

/// A colour per template, and the tile it is shown in.
///
/// The list of things you can start with is the first screen of the app, and it
/// was four grey rows. Colour here is not decoration: it is what lets someone
/// come back a week later and find the one they used, without reading four
/// summaries to work out which.
enum ProjectTemplateStyle {
    static func tint(for templateID: String) -> Color {
        switch templateID {
        case "cli": GopherForgeTheme.gopherBlue
        case "report": Color(hex: 0xB07B00)
        case "worker-pool": GopherForgeTheme.sky
        case "tested-package": Color(hex: 0x4E8F3E)
        default: GopherForgeTheme.slate
        }
    }
}

/// A template, as something you want to press.
struct TemplateTile: View {
    let template: ProjectTemplate

    private var tint: Color { ProjectTemplateStyle.tint(for: template.id) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: template.systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(template.title).font(.callout.weight(.semibold))
                Text(template.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.title). \(template.summary)")
    }
}

/// What the last build said about a project, as a chip.
struct BuildOutcomeChip: View {
    let record: ProjectBuildRecord?

    var body: some View {
        if let record {
            Label(text(for: record), systemImage: symbol(for: record))
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tint(for: record).opacity(0.16), in: Capsule())
                .foregroundStyle(tint(for: record))
        }
    }

    private func text(for record: ProjectBuildRecord) -> String {
        if record.phase == .test, let passed = record.testsPassed, let failed = record.testsFailed {
            return failed == 0 ? "\(passed) tests" : "\(failed) failed"
        }
        return record.succeeded
            ? "\(GopherForgeTheme.label(for: record.phase)) ok"
            : "\(GopherForgeTheme.label(for: record.phase)) failed"
    }

    private func symbol(for record: ProjectBuildRecord) -> String {
        record.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private func tint(for record: ProjectBuildRecord) -> Color {
        record.succeeded ? .green : GopherForgeTheme.warning
    }
}
