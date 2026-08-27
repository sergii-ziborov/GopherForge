import SwiftUI

/// What is known about the module that was looked up, and the button that
/// vendors it.
///
/// Every figure here is attributed. There is no rating service for Go modules,
/// so the app shows the repository's own numbers and the OpenSSF Scorecard,
/// says where they came from, and does not turn them into stars of its own.
struct ResolvedModuleSection: View {
    let resolved: PackageInstallModel.Resolved
    let selectedVersion: String?
    let isBusy: Bool
    let onSelect: (String) -> Void
    let onInstall: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(resolved.path).font(.callout.monospaced())
                if let summary = resolved.insight.summary, !summary.isEmpty {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
                signals
            }
            .padding(.vertical, 2)

            Picker("Version", selection: versionBinding) {
                ForEach(resolved.versions.prefix(30), id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .accessibilityIdentifier(AccessibilityID.packageVersion)

            Button(action: onInstall) {
                Label(
                    selectedVersion.map { "Install \($0)" } ?? "Install",
                    systemImage: "arrow.down.circle"
                )
            }
            .disabled(isBusy || selectedVersion == nil)
            .accessibilityIdentifier(AccessibilityID.packageInstall)

            if !resolved.insight.checks.isEmpty { scorecardChecks }
        } header: {
            Text("Found")
        } footer: {
            Text("Popularity and Scorecard from deps.dev. Scorecard rates a project's "
                + "release and review practices, not whether the code suits you.")
        }
    }

    private var versionBinding: Binding<String> {
        Binding(
            get: { selectedVersion ?? resolved.versions.first ?? "" },
            set: { onSelect($0) }
        )
    }

    @ViewBuilder
    private var signals: some View {
        let insight = resolved.insight
        if insight.hasAnything {
            HStack(spacing: 14) {
                if let score = insight.scorecard {
                    Label(String(format: "%.1f", score), systemImage: "shield.lefthalf.filled")
                        .foregroundStyle(score >= 7 ? Color.green : score >= 4 ? Color.orange : Color.red)
                }
                if let stars = insight.stars {
                    Label(Self.compact(stars), systemImage: "star")
                }
                if let license = insight.license, !license.isEmpty {
                    Label(license, systemImage: "doc.text")
                }
            }
            .font(.caption)
            .accessibilityIdentifier(AccessibilityID.packageSignals)
        } else {
            Text("No published metadata for this module.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// The weakest checks first: a score is only useful if you can see what
    /// pulled it down.
    private var scorecardChecks: some View {
        DisclosureGroup("Scorecard checks") {
            ForEach(resolved.insight.checks.prefix(10)) { check in
                HStack {
                    Text(check.name).font(.caption)
                    Spacer()
                    Text(check.score.map { String(format: "%.0f/10", $0) } ?? "n/a")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func compact(_ value: Int) -> String {
        value >= 1_000 ? String(format: "%.1fk", Double(value) / 1_000) : "\(value)"
    }
}
