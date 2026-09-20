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
