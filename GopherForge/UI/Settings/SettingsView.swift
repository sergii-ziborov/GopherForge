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
    @State private var isConfirmingReset = false
    private let progress = LearningProgressStore.shared

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

            Section {
                Button("Reset learning progress", role: .destructive) {
                    isConfirmingReset = true
                }
                .accessibilityIdentifier(AccessibilityID.settingsResetProgress)
            } header: {
                Text("Progress")
            } footer: {
                Text("Forgets every lesson, drill and quiz, and locks practice again. "
                    + "Projects and their files are untouched.")
            }

            Section("About") {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label("Acknowledgements", systemImage: "text.book.closed")
                }
                .accessibilityIdentifier(AccessibilityID.settingsAcknowledgements)
                LabeledContent("Product", value: "GopherForge")
                Text("Forge real Go, anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task { cacheByteCount = workspace.buildCacheByteCount }
        // Confirmed rather than immediate: this is the one action here that
        // destroys something a person spent time on.
        .confirmationDialog(
            "Reset learning progress?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive) {
                Task { try? await progress.reset() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Every lesson, drill and quiz is forgotten, and practice locks again.")
        }
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
