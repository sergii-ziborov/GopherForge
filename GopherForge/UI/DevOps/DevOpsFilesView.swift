import SwiftUI
import UIKit

/// One file or folder of /lab, for the outline.
struct DevOpsFileNode: Identifiable, Hashable {
    let path: String
    let isDirectory: Bool
    let size: Int
    var children: [DevOpsFileNode]?
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }

    static func tree(_ state: DevOpsLabState, in directory: String = "/lab") -> [DevOpsFileNode] {
        let dirs = state.dirs.keys.filter { $0 != directory && ($0 as NSString).deletingLastPathComponent == directory }
            .map { DevOpsFileNode(path: $0, isDirectory: true, size: 0, children: tree(state, in: $0)) }
        let files = state.files.filter { ($0.key as NSString).deletingLastPathComponent == directory }
            .map { DevOpsFileNode(path: $0.key, isDirectory: false, size: $0.value.utf8.count) }
        return dirs.sorted { $0.name < $1.name } + files.sorted { $0.name < $1.name }
    }
}

/// The lab's files. Everything that changes them goes through the shell, so
/// each action shows up in the terminal as the command it is.
struct DevOpsFilesView: View {
    @Bindable var session: DevOpsLabSession
    /// Inside a sheet the editor is pushed; beside the terminal it is presented.
    var pushesEditor = false
    /// Called before a command runs, so a sheet can get out of the way of its output.
    var onCommand: () -> Void = {}
    @State private var naming: Naming?
    @State private var name = ""
    @State private var pushed: DevOpsEditorRequest?

    private enum Naming: Identifiable { case file, folder; var id: Self { self } }

    var body: some View {
        if pushesEditor {
            list.navigationDestination(item: $pushed) { request in
                DevOpsFileEditor(session: session, request: request, presented: false, onRun: onCommand)
            }
        } else {
            list
        }
    }

    private var list: some View {
        let nodes = DevOpsFileNode.tree(session.state)
        return List {
            Section {
                if nodes.isEmpty {
                    Text("No files yet. Create one here, or type touch notes.txt in the terminal.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                OutlineGroup(nodes, children: \.children) { node in row(node) }
            } header: {
                HStack {
                    Label(session.promptDirectory, systemImage: "folder")
                    Spacer()
                    Text(usage)
                    Menu {
                        Button("New file", systemImage: "doc.badge.plus") { name = ""; naming = .file }
                        Button("New folder", systemImage: "folder.badge.plus") { name = ""; naming = .folder }
                    } label: { Label("New", systemImage: "plus.circle.fill").labelStyle(.iconOnly).font(.title3) }
                    .accessibilityIdentifier("devops.files.new")
                }
                .font(.caption)
            } footer: {
                Text("Your private /lab: up to 128 files and folders, 64 KiB per file, 2 MiB in all. It works offline and never leaves the device.")
            }
        }
        .listStyle(.insetGrouped)
        .alert(naming == .folder ? "New folder" : "New file", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField(naming == .folder ? "configs" : "notes.txt", text: $name)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Create") { create() }
        } message: {
            Text("Inside \(session.promptDirectory). Use slashes for nested paths.")
        }
    }

    private var usage: String {
        let bytes = session.state.files.values.reduce(0) { $0 + $1.utf8.count }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) + " of 2 MB"
    }

    @ViewBuilder private func row(_ node: DevOpsFileNode) -> some View {
        let label = Label {
            HStack {
                Text(node.name).font(.body.monospaced())
                Spacer()
                if !node.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(node.size), countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: node.isDirectory ? "folder.fill" : node.name.hasSuffix(".sh") ? "terminal" : "doc.text")
                .foregroundStyle(node.isDirectory ? GopherForgeTheme.accent : .secondary)
        }
        Group {
            if node.isDirectory {
                label
            } else {
                Button { edit(node.path) } label: { label }.tint(.primary)
            }
        }
        .accessibilityIdentifier("devops.file.\(node.name)")
        .contextMenu {
            if !node.isDirectory {
                Button("Edit", systemImage: "pencil") { edit(node.path) }
                Button("Print with cat", systemImage: "text.alignleft") { command("cat " + shellPath(node.path)) }
                if node.name.hasSuffix(".sh") {
                    Button("Run", systemImage: "play") { command("sh " + shellPath(node.path)) }
                }
            } else {
                Button("Open in terminal", systemImage: "terminal") { command("cd " + shellPath(node.path) + " && ls -la") }
            }
            Button("Insert path at prompt", systemImage: "text.cursor") { onCommand(); session.type(shellPath(node.path)) }
            Button("Delete", systemImage: "trash", role: .destructive) { remove(node) }
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) { remove(node) }
        }
    }

    private func edit(_ path: String) {
        if pushesEditor {
            pushed = session.editorRequest(for: path)
        } else {
            session.openEditor(path)
        }
    }

    /// Deleting stays in the list, which updates as the shell removes the file.
    private func remove(_ node: DevOpsFileNode) {
        Task { await session.perform((node.isDirectory ? "rm -r " : "rm ") + shellPath(node.path)) }
    }

    /// A path as you would type it: relative to ~, quoted when it needs to be.
    private func shellPath(_ path: String) -> String {
        let shown = DevOpsLabSession.abbreviate(path)
        return shown.contains(where: { " '\"$`\\*?&;|<>()".contains($0) }) ? "'" + shown.replacingOccurrences(of: "'", with: "'\\''") + "'" : shown
    }

    private func command(_ line: String) {
        onCommand()
        Task { await session.perform(line) }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch naming {
        case .folder: command("mkdir -p " + shellPath(session.resolve(trimmed) ?? trimmed))
        case .file:
            guard let path = session.resolve(trimmed) else { return }
            let parent = (path as NSString).deletingLastPathComponent
            if session.state.dirs[parent] != true {
                Task {
                    await session.perform("mkdir -p " + shellPath(parent))
                    edit(path)
                }
            } else {
                edit(path)
            }
        case nil: break
        }
        naming = nil
    }
}

/// A plain text editor for one lab file, with the shell's limits shown.
struct DevOpsFileEditor: View {
    @Bindable var session: DevOpsLabSession
    let request: DevOpsEditorRequest
    /// Presented as a sheet rather than pushed onto a stack.
    var presented = true
    /// Called before Save and run starts the script.
    var onRun: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loaded = false
    @State private var failure: String?

    var body: some View {
        DevOpsTextEditor(text: $text)
            .ignoresSafeArea(.container, edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text(DevOpsLabSession.abbreviate(request.path)).lineLimit(1).truncationMode(.head)
                    Spacer()
                    Text("\(lineCount) lines · \(text.utf8.count) of 65536 bytes")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(text.utf8.count > 65_536 ? .red : .secondary)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle(request.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presented {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(thenRun: false) }
                        .disabled(text.utf8.count > 65_536)
                        .accessibilityIdentifier("devops.editor.save")
                }
                if request.name.hasSuffix(".sh") {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Save and run", systemImage: "play.fill") { save(thenRun: true) }
                    }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = request.contents
            }
            .alert("Could not save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(failure ?? "") }
    }

    private var lineCount: Int { text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count }

    private func save(thenRun: Bool) {
        do {
            try session.save(text, to: request.path)
            dismiss()
            if thenRun {
                onRun()
                Task { await session.perform("sh " + DevOpsLabSession.abbreviate(request.path)) }
            }
        } catch { failure = error.localizedDescription }
    }
}

/// A monospaced text view without the smart quotes, dashes and corrections
/// that would quietly break a script.
struct DevOpsTextEditor: UIViewRepresentable {
    @Binding var text: String
    @AppStorage("devops.terminal.fontSize") private var fontSize = DevOpsTerminalStyle.defaultFontSize

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.backgroundColor = DevOpsTerminalStyle.uiBackground
        view.textColor = UIColor(DevOpsTerminalStyle.text)
        view.tintColor = UIColor(DevOpsTerminalStyle.prompt)
        view.keyboardAppearance = .dark
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.keyboardType = .asciiCapable
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        view.accessibilityIdentifier = "devops.editor.text"
        view.delegate = context.coordinator
        view.text = text
        // Like nano, the editor opens ready to type.
        DispatchQueue.main.async { [weak view] in
            guard let view, view.window != nil else { return }
            view.becomeFirstResponder()
            view.selectedRange = NSRange(location: (view.text as NSString).length, length: 0)
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
        if view.font?.pointSize != CGFloat(fontSize) { view.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ view: UITextView) { text.wrappedValue = view.text }
    }
}
