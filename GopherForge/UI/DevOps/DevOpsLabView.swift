import SwiftUI

/// A lab, or the free playground: a terminal first, with the lab's files and,
/// for guided labs, the task and its checks beside it on iPad or a tap away
/// on iPhone.
struct DevOpsLabView: View {
    @State private var session: DevOpsLabSession
    @State private var resetting = false
    @State private var showingFiles = false
    @State private var showingGuide = false
    @State private var sidebarPanel = SidebarPanel.guide
    @State private var editingScript = false
    @AppStorage("devops.terminal.fontSize") private var fontSize = DevOpsTerminalStyle.defaultFontSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private enum SidebarPanel: String, CaseIterable { case guide = "Lab", files = "Files" }

    init(lab: DevOpsLab) { _session = State(initialValue: DevOpsLabSession(lab: lab)) }

    private var guided: Bool { !session.lab.checks.isEmpty }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    sidebar.frame(width: 340)
                    Divider()
                    terminal
                }
            } else {
                VStack(spacing: 0) {
                    if guided { taskBar }
                    terminal
                }
            }
        }
        .navigationTitle(guided ? session.lab.title : "Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(DevOpsTerminalStyle.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbar }
        .sheet(isPresented: $showingFiles) {
            NavigationStack {
                DevOpsFilesView(session: session, pushesEditor: true) { showingFiles = false }
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingFiles = false } } }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                guide { showingGuide = false }
                    .navigationTitle(session.lab.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingGuide = false } } }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
        // The terminal and everything it opens stay dark, as one workspace.
        .sheet(item: $session.editor) { request in
            NavigationStack { DevOpsFileEditor(session: session, request: request) }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $editingScript) {
            NavigationStack { DevOpsScriptEditor(session: session) }
                .preferredColorScheme(.dark)
        }
        .confirmationDialog(guided ? "Reset this lab?" : "Reset the playground?", isPresented: $resetting, titleVisibility: .visible) {
            Button(guided ? "Reset lab files" : "Reset playground files", role: .destructive) { session.reset() }
        } message: {
            Text(guided
                ? "Only files in this lab return to their starting state. Your projects, other labs and course progress are kept."
                : "Every file, variable and function in the playground is removed. Your labs, projects and course progress are kept.")
        }
        .onChange(of: session.exitRequested) { _, exit in if exit { dismiss() } }
        .onDisappear { session.stop(); session.saveDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.stop(); session.saveDraft() } }
    }

    private var terminal: some View {
        VStack(spacing: 0) {
            if let message = session.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.white)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.75))
            }
            DevOpsTerminalView(session: session)
        }
        .background(DevOpsTerminalStyle.background)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if sizeClass != .regular {
                Button { showingFiles = true } label: { Label("Files", systemImage: "folder") }
                    .accessibilityIdentifier("devops.files")
            }
            Menu {
                Button("Clear screen", systemImage: "eraser") { session.clear() }
                Button("Commands", systemImage: "questionmark.circle") { Task { await session.perform("help") } }
                Section("Text size") {
                    Button("Larger", systemImage: "textformat.size.larger") { fontSize = min(fontSize + 1, 22) }
                    Button("Smaller", systemImage: "textformat.size.smaller") { fontSize = max(fontSize - 1, 10) }
                }
                Button(guided ? "Reset lab…" : "Reset playground…", systemImage: "arrow.counterclockwise", role: .destructive) { resetting = true }
                    .disabled(session.isRunning)
            } label: { Label("More", systemImage: "ellipsis.circle") }
            .accessibilityIdentifier("devops.menu")
        }
    }

    /// The lab's goal and progress above the terminal on iPhone.
    private var taskBar: some View {
        let checks = session.checks
        let passed = checks.filter(\.passed).count
        return HStack(spacing: 12) {
            Button { showingGuide = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: passed == checks.count ? "checkmark.seal.fill" : "list.bullet.clipboard")
                        .font(.title3)
                        .foregroundStyle(passed == checks.count ? .green : DevOpsTerminalStyle.path)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.lab.objective).font(.subheadline.weight(.semibold)).lineLimit(2)
                            .foregroundStyle(DevOpsTerminalStyle.text)
                        Text("\(passed) of \(checks.count) checks passed · Lab guide")
                            .font(.caption).foregroundStyle(DevOpsTerminalStyle.dim)
                            .accessibilityIdentifier("devops.checks")
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("devops.guide")
            Button { Task { await session.run() } } label: { Label("Run script", systemImage: "play.fill") }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .disabled(session.isRunning || session.needsReset)
                .accessibilityIdentifier("devops.run")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(DevOpsTerminalStyle.surface)
        .environment(\.colorScheme, .dark)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if guided {
                Picker("Panel", selection: $sidebarPanel) {
                    ForEach(SidebarPanel.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(12)
            }
            if guided && sidebarPanel == .guide {
                guide {}
            } else {
                DevOpsFilesView(session: session)
            }
        }
        .background(Color(.systemGroupedBackground))
        .environment(\.colorScheme, .dark)
    }

    /// The lab's task, its script and its checks.
    private func guide(onRun: @escaping () -> Void) -> some View {
        let checks = session.checks
        return List {
            Section("Goal") {
                Text(session.lab.objective).font(.headline)
                Text(session.lab.instructions).textSelection(.enabled)
            }
            Section {
                Text(session.source.isEmpty ? "# empty" : session.source)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("devops.source")
                Button("Run script", systemImage: "play.fill") { onRun(); Task { await session.run() } }
                    .disabled(session.isRunning || session.needsReset)
                    .accessibilityIdentifier(sizeClass == .regular ? "devops.run" : "devops.guide.run")
                // A sheet cannot present another, so on iPhone the editor is pushed.
                if sizeClass == .regular {
                    Button("Edit script", systemImage: "pencil") { editingScript = true }
                } else {
                    NavigationLink { DevOpsScriptEditor(session: session, pushed: true, onRun: onRun) } label: {
                        Label("Edit script", systemImage: "pencil")
                    }
                }
            } header: { Text("Script") } footer: {
                Text("Run sends the whole script to the terminal. You can also type each command yourself.")
            }
            Section {
                ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                    Label(check.description, systemImage: check.passed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(check.passed ? .green : .secondary)
                }
            } header: {
                Text("Checks · \(checks.filter(\.passed).count) of \(checks.count) passed")
                    .accessibilityIdentifier(sizeClass == .regular ? "devops.checks" : "devops.guide.checks")
            } footer: {
                Text("Checks read the actual files in this lab after every command.")
            }
            Section {
                Button("Reset lab…", systemImage: "arrow.counterclockwise", role: .destructive) { resetting = true }
                    .disabled(session.isRunning)
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// Edits the guided lab's script, which Run executes as a whole.
private struct DevOpsScriptEditor: View {
    @Bindable var session: DevOpsLabSession
    var pushed = false
    /// Called before Save and run starts the script.
    var onRun: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        DevOpsTextEditor(text: $text)
            .navigationTitle("Lab script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !pushed {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { session.source = text; dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Save and run", systemImage: "play.fill") {
                        session.source = text
                        dismiss()
                        onRun()
                        Task { await session.run() }
                    }
                }
            }
            .onAppear { text = session.source }
    }
}
