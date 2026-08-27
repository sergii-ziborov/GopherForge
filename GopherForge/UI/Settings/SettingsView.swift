import SwiftUI

/// Settings, and the honest statement of what the app can and cannot do.
struct SettingsView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("keepAwakeDuringBuilds") private var keepAwake = false

    var body: some View {
        Form {
            Section("Editor") {
                Stepper(value: $fontSize, in: 11...22, step: 1) {
                    LabeledContent("Text size", value: "\(Int(fontSize)) pt")
                }
                Toggle("Keep the screen awake while building", isOn: $keepAwake)
            }

            Section("Toolchain") {
                LabeledContent("Status", value: workspace.toolchain.label)
                    .accessibilityIdentifier(AccessibilityID.settingsToolchainStatus)
                if workspace.toolchain.isReady {
                    LabeledContent("Go version", value: workspace.toolchain.goVersion)
                    LabeledContent("Driver size", value: formattedSize)
                }
                Text(workspace.toolchain.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Boundaries") {
                BoundaryRow(
                    supported: true,
                    text: "The compiler ships inside the app and runs with no network."
                )
                BoundaryRow(
                    supported: true,
                    text: "Programs run in a sandbox with one writable directory and no network."
                )
                BoundaryRow(
                    supported: false,
                    text: "cgo is not supported: it needs a native C toolchain."
                )
                BoundaryRow(
                    supported: false,
                    text: "Modules are not downloaded; dependencies must be vendored."
                )
            }

            Section("About") {
                LabeledContent("Product", value: "GopherForge")
                Text("Forge real Go, anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: workspace.toolchain.driverSize,
            countStyle: .file
        )
    }
}

private struct BoundaryRow: View {
    let supported: Bool
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: supported ? "checkmark.circle.fill" : "minus.circle.fill")
                .foregroundStyle(supported ? Color.green : Color.secondary)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
