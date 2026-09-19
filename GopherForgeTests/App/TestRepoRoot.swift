import Foundation

/// The checkout root, found by walking up from a test file until `project.yml`.
///
/// Tests that read docs or entitlements cannot count `../` hops: those change
/// whenever a file moves into a topic folder.
enum TestRepoRoot {
    static func url(from filePath: String = #filePath) throws -> URL {
        var url = URL(fileURLWithPath: filePath)
        for _ in 0..<16 {
            if FileManager.default.fileExists(atPath: url.appending(path: "project.yml").path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
