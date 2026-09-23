import Foundation

/// Jumping to a diagnostic and dropping the mark once that line is edited.
extension WorkspaceModel {
    /// The line opened from a diagnostic, and only that line. Every error in
    /// the last result used to stay painted; tapping one is what says "look
    /// here", and the mark has to be able to go away.
    var markedLines: Set<Int> {
        guard let focusedErrorLine, focusedErrorFile == selectedFile else { return [] }
        return [focusedErrorLine]
    }

    /// Opens a file and, when a line is given, asks the editor to reveal it.
    func select(file: String, revealingLine line: Int?) {
        select(file: file)
        revealLine = line
        if let line {
            focusedErrorFile = file
            focusedErrorLine = line
        }
    }

    /// Called by the editor once it has scrolled, so a later redraw does not
    /// yank the view back.
    func clearReveal() {
        revealLine = nil
    }

    func select(file: String) {
        commitEditorText()
        selectedFile = file
        replaceEditorText(project?.files[file] ?? "")
        highlightQuery = ""
        clearFocusedError()
    }

    /// The one way the editor changes text.
    ///
    /// It folds the buffer into the project immediately and schedules the disk
    /// write. Both halves matter: the in-memory project is what Export, the
    /// package installer and every phase read, and the library is what
    /// survives the app being closed.
    ///
    /// The editor used to write `editorText` and nothing else, and the project
    /// caught up only when something asked for it — a build, or opening
    /// another file. So anything typed and not built lived in a buffer nobody
    /// persisted: leaving the tab and vendoring a package overwrote it from a
    /// stale project, and quitting lost it outright. Losing what someone typed
    /// is worse than any missing language feature.
    func updateEditorText(_ text: String) {
        guard text != editorText else { return }
        if let line = focusedErrorLine, focusedErrorFile == selectedFile,
           Self.line(editorText, number: line) != Self.line(text, number: line) {
            clearFocusedError()
        }
        replaceEditorText(text)
        commitEditorText()
    }

    func clearFocusedError() {
        focusedErrorFile = nil
        focusedErrorLine = nil
    }

    /// One 1-based source line, or empty if that number is past the end.
    static func line(_ source: String, number: Int) -> String {
        var current = 1
        var start = source.startIndex
        while start < source.endIndex {
            let end = source[start...].firstIndex(of: "\n") ?? source.endIndex
            if current == number {
                return String(source[start..<end])
            }
            current += 1
            start = end == source.endIndex ? end : source.index(after: end)
        }
        return ""
    }
}

enum ProjectFileError: LocalizedError {
    case invalidName
    case alreadyExists
    case notFound
    case protectedFile
    case lastFile

    var errorDescription: String? {
        switch self {
        case .invalidName: "Choose a name without slashes, reserved names, or control characters."
        case .alreadyExists: "A file or folder with that name already exists."
        case .notFound: "That file or folder is no longer in this project."
        case .protectedFile: "Installed packages are managed from Packages."
        case .lastFile: "A project needs at least one file."
        }
    }
}

extension WorkspaceModel {
    /// An empty directory is recorded by a hidden marker so it survives a save
    /// or archive without introducing a second, unsynchronised folder model.
    @discardableResult
    func createFolder(named name: String, in directory: String = "") throws -> String {
        let path = try newPath(named: name, in: directory)
        var files = try currentFiles()
        guard directory.isEmpty || files.keys.contains(where: { $0.hasPrefix(directory + "/") }) else {
            throw ProjectFileError.notFound
        }
        guard !hasPath(path, in: files) else { throw ProjectFileError.alreadyExists }
        files[path + "/" + GopherForgeProject.folderMarker] = ""
        replaceFiles(with: files)
        return path
    }

    @discardableResult
    func createFile(named name: String, in directory: String = "") throws -> String {
        let path = try newPath(named: name, in: directory)
        var files = try currentFiles()
        guard directory.isEmpty || files.keys.contains(where: { $0.hasPrefix(directory + "/") }) else {
            throw ProjectFileError.notFound
        }
        guard !hasPath(path, in: files) else { throw ProjectFileError.alreadyExists }
        let package = files.keys.sorted().first { candidate in
            GoPackageGraph.directory(of: candidate) == directory
                && candidate.hasSuffix(".go") && !candidate.hasSuffix("_test.go")
        }.map { GoSourceHeader.parse(files[$0] ?? "").packageName }
        let fallback = directory.split(separator: "/").last.map(String.init) ?? "main"
        let identifier = fallback.replacingOccurrences(
            of: "[^A-Za-z0-9_]", with: "_", options: .regularExpression
        )
        let source = path.hasSuffix(".go")
            ? "package \(package.flatMap { $0.isEmpty ? nil : $0 } ?? (identifier.first?.isNumber == true || identifier == "_" ? "main" : identifier))\n\n"
            : ""
        files[path] = source
        replaceFiles(with: files)
        select(file: path)
        return path
    }

    func renameFile(at path: String, to name: String) throws {
        guard !GoVendorWriter.isVendoredPath(path) else { throw ProjectFileError.protectedFile }
        let destination = try newPath(named: name, in: GoPackageGraph.directory(of: path))
        if destination == path { return }
        var files = try currentFiles()
        guard let contents = files.removeValue(forKey: path) else { throw ProjectFileError.notFound }
        guard !hasPath(destination, in: files) else { throw ProjectFileError.alreadyExists }
        files[destination] = contents
        let entry = project?.entryFile == path ? destination : project?.entryFile
        applyFileChange(files, entryFile: entry, selectedFile: selectedFile == path ? destination : selectedFile)
    }

    func deleteFile(at path: String) throws {
        guard !GoVendorWriter.isVendoredPath(path) else { throw ProjectFileError.protectedFile }
        var files = try currentFiles()
        guard files.removeValue(forKey: path) != nil else { throw ProjectFileError.notFound }
        let remaining = files.keys.filter { !$0.hasSuffix("/" + GopherForgeProject.folderMarker) }
        guard !remaining.isEmpty else { throw ProjectFileError.lastFile }
        let entry = project?.entryFile == path ? preferredEntry(in: remaining) : project?.entryFile
        applyFileChange(files, entryFile: entry, selectedFile: selectedFile == path ? entry ?? "" : selectedFile)
    }

    func renameFolder(at directory: String, to name: String) throws {
        guard !directory.isEmpty, !GoVendorWriter.isVendoredPath(directory) else {
            throw ProjectFileError.protectedFile
        }
        let destination = try newPath(named: name, in: GoPackageGraph.directory(of: directory))
        if destination == directory { return }
        var files = try currentFiles()
        guard files.keys.contains(where: { $0.hasPrefix(directory + "/") }) else {
            throw ProjectFileError.notFound
        }
        guard !hasPath(destination, in: files) else { throw ProjectFileError.alreadyExists }
        for key in files.keys.filter({ $0.hasPrefix(directory + "/") }) {
            files[destination + key.dropFirst(directory.count)] = files.removeValue(forKey: key)
        }
        func moved(_ path: String) -> String {
            path.hasPrefix(directory + "/") ? destination + path.dropFirst(directory.count) : path
        }
        let entry = project.map { moved($0.entryFile) }
        applyFileChange(files, entryFile: entry, selectedFile: moved(selectedFile))
    }

    func deleteFolder(at directory: String) throws {
        guard !directory.isEmpty, !GoVendorWriter.isVendoredPath(directory) else {
            throw ProjectFileError.protectedFile
        }
        var files = try currentFiles()
        let descendants = files.keys.filter { $0.hasPrefix(directory + "/") }
        guard !descendants.isEmpty else { throw ProjectFileError.notFound }
        for key in descendants { files.removeValue(forKey: key) }
        let remaining = files.keys.filter { !$0.hasSuffix("/" + GopherForgeProject.folderMarker) }
        guard !remaining.isEmpty else { throw ProjectFileError.lastFile }
        let entry = project?.entryFile ?? ""
        let nextEntry = descendants.contains(entry) ? preferredEntry(in: remaining) : entry
        let nextSelected = descendants.contains(selectedFile) ? nextEntry : selectedFile
        applyFileChange(files, entryFile: nextEntry, selectedFile: nextSelected)
    }

    private func currentFiles() throws -> [String: String] {
        commitEditorText()
        guard let project else { throw ProjectFileError.notFound }
        return project.files
    }

    private func newPath(named rawName: String, in directory: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", name != GopherForgeProject.folderMarker,
              !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
              name.rangeOfCharacter(from: .controlCharacters) == nil,
              !(directory.isEmpty && name == "vendor"),
              directory != "vendor", !GoVendorWriter.isVendoredPath(directory)
        else { throw ProjectFileError.invalidName }
        return directory.isEmpty ? name : directory + "/" + name
    }

    private func hasPath(_ path: String, in files: [String: String]) -> Bool {
        files[path] != nil || files.keys.contains { $0.hasPrefix(path + "/") }
    }

    private func preferredEntry(in paths: [String]) -> String {
        paths.sorted { left, right in
            if left.hasSuffix(".go") != right.hasSuffix(".go") { return left.hasSuffix(".go") }
            return left < right
        }.first ?? ""
    }

}
