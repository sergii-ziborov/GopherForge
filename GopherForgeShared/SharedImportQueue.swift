import Foundation

/// The hand-off between the share extension and the app.
///
/// The extension never tries to foreground the host app: it validates, queues
/// and tells the user it was queued. The app drains the queue the next time it
/// runs, which is the only behaviour that works reliably on iOS.
enum SharedImportQueue {
    static let appGroupIdentifier = "group.com.sergiiziborov.GopherForge"
    private static let storageKey = "pendingGitHubImportURLs"
    private static let maximumPendingImports = 10

    @discardableResult
    static func enqueue(_ rawURL: String) throws -> GitHubRepositoryReference {
        let reference = try GitHubRepositoryReference.parse(rawURL)
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw QueueError.appGroupUnavailable
        }
        var values = defaults.stringArray(forKey: storageKey) ?? []
        values.removeAll { $0 == rawURL }
        values.append(rawURL)
        if values.count > maximumPendingImports {
            values.removeFirst(values.count - maximumPendingImports)
        }
        defaults.set(values, forKey: storageKey)
        return reference
    }

    static func dequeue() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        var values = defaults.stringArray(forKey: storageKey) ?? []
        guard !values.isEmpty else { return nil }
        let value = values.removeFirst()
        defaults.set(values, forKey: storageKey)
        return value
    }

    enum QueueError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            "GopherForge could not access its shared import queue."
        }
    }
}
