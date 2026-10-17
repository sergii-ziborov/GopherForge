import SwiftUI

/// Settings, and the honest statement of what the app can and cannot do.
struct SettingsView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @AppStorage("editorFontSize") private var fontSize: Double = 14
    @AppStorage("keepAwakeDuringBuilds") private var keepAwake = false
    @AppStorage(AppLock.storageKey) private var requireFaceID = false
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue
    /// Read once when the screen appears rather than on every redraw: it walks
    /// a directory, and Settings redraws for every stepper tick.
    @State private var cacheByteCount: Int64 = 0
    @State private var packageStorage = GoPackageStorage.Summary()
    @State private var packageStorageError: String?
    @State private var isConfirmingPackageCleanup = false
    @State private var isConfirmingReset = false
    @State private var libraryUsesChosenFolder = ProjectLibraryLocation.usesChosenFolder
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

            Section("Projects") {
                LabeledContent(
                    "Library",
                    value: libraryUsesChosenFolder
                        ? "iCloud / Files folder"
                        : "On this device"
                )
                if libraryUsesChosenFolder {
                    Button("Keep library on this device") {
                        Task {
                            _ = try? await ProjectLibrary.shared.useOnDeviceLibrary()
                            libraryUsesChosenFolder = ProjectLibraryLocation.usesChosenFolder
                        }
                    }
                }
                Text("Open a `.tar.gz` or folder from iCloud Drive on Projects, "
                    + "or pick a folder there to keep the whole library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Editor") {
                Stepper(value: $fontSize, in: 11...22, step: 1) {
                    LabeledContent("Text size", value: "\(Int(fontSize)) pt")
                }
                Toggle("Keep the screen awake", isOn: $keepAwake)
                Text("While a build or a package download is running, the screen stays on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Require Face ID", isOn: Binding(
                    get: { requireFaceID },
                    set: { enabled in
                        guard enabled else {
                            requireFaceID = false
                            return
                        }
                        Task {
                            if await AppLock.authenticate() {
                                requireFaceID = true
                            }
                        }
                    }
                ))
            } header: {
                Text("Lock")
            } footer: {
                Text("When you leave GopherForge, Face ID or the device passcode is required to come back. A download keeps going underneath.")
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
                Text("Forgets every lesson, drill, quiz and mistake correction. "
                    + "Projects and their files are untouched.")
            }

            Section {
                LabeledContent("Package source", value: ByteCountFormatter.string(
                    fromByteCount: packageStorage.byteCount, countStyle: .file
                ))
                Text("\(packageStorage.projectCount) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear downloaded packages", role: .destructive) {
                    isConfirmingPackageCleanup = true
                }
                .disabled(packageStorage.fileCount == 0 || workspace.isRunning
                    || workspace.downloadProgress != nil || workspace.isClearingPackages)
                .accessibilityIdentifier("settings.clearPackages")
                if let packageStorageError {
                    Text(packageStorageError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Downloaded packages")
            } footer: {
                Text("Clears dependency source from all your saved projects. Your code and dependency versions stay. Packages download again when needed. Lessons and built-in Examples are excluded.")
            }

            Section("About") {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label("Third-Party Library", systemImage: "text.book.closed")
                }
                .accessibilityIdentifier(AccessibilityID.settingsAcknowledgements)
                // Required in the app, not only in App Store Connect: guideline
                // 5.1.1(i) asks for the privacy policy to be reachable from
                // inside the app, and a listing link alone does not satisfy it.
                Link(destination: AppLinks.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .accessibilityIdentifier(AccessibilityID.settingsPrivacyPolicy)

                Link(destination: AppLinks.termsOfUse) {
                    Label("Terms of Use", systemImage: "doc.text")
                }
                .accessibilityIdentifier("settings.termsOfUse")

                Link(destination: AppLinks.support) {
                    Label("Support", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier(AccessibilityID.settingsSupport)

                Link(destination: AppLinks.writeReview) {
                    Label("Rate GopherForge", systemImage: "star")
                }
                .accessibilityIdentifier(AccessibilityID.settingsWriteReview)

                LabeledContent("Product", value: "GopherForge")
                LabeledContent("Version", value: AppLinks.versionSummary)
                    .accessibilityIdentifier(AccessibilityID.settingsVersion)
                Text("Forge real Go, anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear { libraryUsesChosenFolder = ProjectLibraryLocation.usesChosenFolder }
        .task {
            cacheByteCount = workspace.buildCacheByteCount
            await refreshPackageStorage()
        }
        .confirmationDialog(
            "Clear downloaded packages from all your projects?",
            isPresented: $isConfirmingPackageCleanup,
            titleVisibility: .visible
        ) {
            Button("Clear downloaded packages", role: .destructive) {
                Task {
                    do {
                        _ = try await workspace.clearDownloadedPackages()
                        await refreshPackageStorage()
                    } catch {
                        packageStorageError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your code, dependency versions, lessons and Examples stay. Building your projects will need the internet to download their packages again.")
        }
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
            Text("Every lesson, drill, quiz and mistake correction is forgotten.")
        }
    }

    private var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheByteCount, countStyle: .file)
    }

    private func refreshPackageStorage() async {
        do {
            packageStorage = try await workspace.downloadedPackageStorage()
            packageStorageError = nil
        } catch {
            packageStorageError = error.localizedDescription
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: workspace.toolchain.toolSize,
            countStyle: .file
        )
    }
}
