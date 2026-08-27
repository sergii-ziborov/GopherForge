import SwiftUI

/// Settings, and the honest statement of what the app can and cannot do.
struct SettingsView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("keepAwakeDuringBuilds") private var keepAwake = false
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue
    /// Read once when the screen appears rather than on every redraw: it walks
    /// a directory, and Settings redraws for every stepper tick.
    @State private var cacheByteCount: Int64 = 0

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.settingsAppearance)
            }

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
                    LabeledContent("Compiler and linker", value: formattedSize)
                }
                Text(workspace.toolchain.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if workspace.toolchain.isReady {
                Section("Build cache") {
                    LabeledContent("Stored programs", value: formattedCacheSize)
                    Button("Clear build cache", role: .destructive) {
                        workspace.clearBuildCache()
                        cacheByteCount = workspace.buildCacheByteCount
                    }
                    .accessibilityIdentifier(AccessibilityID.settingsClearCache)
                    Text("Compiled programs are kept so an unchanged one runs at once. "
                        + "Clearing them frees the space and makes the next run compile again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Product", value: "GopherForge")
                Text("Forge real Go, anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task { cacheByteCount = workspace.buildCacheByteCount }
    }

    private var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheByteCount, countStyle: .file)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: workspace.toolchain.toolSize,
            countStyle: .file
        )
    }
}
