import Foundation

/// Where the project library lives, and how a person can put it in iCloud.
///
/// The default is Application Support on this device. Choosing a folder from
/// Files — including iCloud Drive — stores a security-scoped bookmark and
/// writes the same JSON there, so the library can follow the owner without
/// an iCloud container entitlement that would fail a Cloud archive if the
/// App ID did not have the capability enabled.
enum ProjectLibraryLocation {
    static let bookmarkDefaultsKey = "gopherforge.library.folder.bookmark"

    static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appending(path: "GopherForge", directoryHint: .isDirectory)
            .appending(path: "recent-projects.json")
    }

    /// The file the library should read and write right now.
    static func fileURL() -> URL {
        if let folder = rememberedFolder() {
            return folder.appending(path: "recent-projects.json")
        }
        return defaultFileURL()
    }

    static var usesChosenFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkDefaultsKey) != nil
    }

    /// Remembers a folder the owner picked in Files or iCloud Drive.
    static func remember(folder url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: bookmarkDefaultsKey)
    }

    static func forgetChosenFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkDefaultsKey)
    }

    /// Resolves the bookmark and begins the security scope. The library
    /// holds that access for the rest of the process; iOS revokes it when
    /// the app is killed.
    static func rememberedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else {
            return nil
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }
        _ = url.startAccessingSecurityScopedResource()
        if stale {
            try? remember(folder: url)
        }
        return url
    }
}
