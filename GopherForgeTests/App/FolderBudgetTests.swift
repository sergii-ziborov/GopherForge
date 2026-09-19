import XCTest
@testable import GopherForge

/// No product or test folder may hold more than ten Swift files.
///
/// A folder that grows past that is a bag of unrelated types. The cap is the
/// thing that forces a split before the next feature lands in the wrong place.
final class FolderBudgetTests: XCTestCase {
    private static let maximumFiles = 10
    private static let skippedFolderNames: Set<String> = [
        "VendoredModules", "Toolchain", "DerivedData", "build", ".git",
    ]

    func testNoFolderHoldsMoreThanTenSwiftFiles() throws {
        let root = try TestRepoRoot.url()
        var offenders: [String] = []
        for tree in ["GopherForge", "GopherForgeTests", "GopherForgeUITests", "GopherForgeShare", "GopherForgeShared"] {
            let url = root.appending(path: tree)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            offenders.append(contentsOf: Self.offenders(under: url))
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "folders with more than \(Self.maximumFiles) Swift files:\n"
                + offenders.joined(separator: "\n")
        )
    }

    private static func offenders(under root: URL) -> [String] {
        var byDirectory: [String: [String]] = [:]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            if url.pathComponents.contains(where: { skippedFolderNames.contains($0) }) {
                continue
            }
            byDirectory[url.deletingLastPathComponent().path, default: []].append(url.lastPathComponent)
        }
        return byDirectory
            .filter { $0.value.count > maximumFiles }
            .sorted { $0.key < $1.key }
            .map { "\($0.value.count) \($0.key.replacingOccurrences(of: root.path, with: root.lastPathComponent))\n    \($0.value.sorted().joined(separator: ", "))" }
    }
}
