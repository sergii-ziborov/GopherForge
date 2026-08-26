import Foundation

/// Drains whatever the share extension queued while the app was not running.
///
/// The extension can only queue; it cannot foreground the app. So the app has
/// to look, and it looks once at launch rather than polling.
struct PendingImportDrain: Sendable {
    struct Pending: Identifiable, Equatable, Sendable {
        let reference: GitHubRepositoryReference
        let rawURL: String
        var id: String { rawURL }
    }

    func drain(limit: Int = 10) -> [Pending] {
        var pending: [Pending] = []
        while pending.count < limit, let rawURL = SharedImportQueue.dequeue() {
            // A URL that no longer parses is dropped rather than surfaced: it
            // was validated when queued, so this only happens if the queue was
            // written by something else.
            guard let reference = try? GitHubRepositoryReference.parse(rawURL) else { continue }
            pending.append(Pending(reference: reference, rawURL: rawURL))
        }
        return pending
    }
}
