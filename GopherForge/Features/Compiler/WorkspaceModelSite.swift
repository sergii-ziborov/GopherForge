import Foundation

extension WorkspaceModel {
    /// Starts or refreshes the on-device site for a project that has pages.
    ///
    /// Called after open, after a run, and after an edit that might have
    /// changed a page. A project with no HTML drops the listen.
    func refreshSitePreview() {
        guard let files = project?.files, LocalSiteFiles.isSite(files) else {
            siteServer.stop()
            sitePreviewURL = nil
            return
        }
        do {
            try siteServer.publish(files)
            sitePreviewURL = siteServer.url
            siteGeneration += 1
        } catch {
            sitePreviewURL = nil
        }
    }

    /// Pushes the current buffers to a listen that is already up, without
    /// reloading the preview on every keystroke.
    func syncSiteFiles() {
        guard let files = project?.files, siteServer.isListening else { return }
        try? siteServer.publish(files)
    }
}
