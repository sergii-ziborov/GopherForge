import XCTest
@testable import GopherForge

final class ProjectImportIntegrityTests: XCTestCase {
    func testInventoryRetainsFixturesVendorCIAndReactAndRecordsEveryOmission() throws {
        var report = ProjectImportReport()
        let paths = ["main.go", "go.mod", "testdata/input.json", "testdata/users.csv", "vendor/x/x.go", ".github/workflows/ci.yml", "web/App.tsx", "web/main.jsx"]
        var entries = Dictionary(uniqueKeysWithValues: paths.map { ($0, Data("text".utf8)) })
        entries["assets/logo.png"] = Data([1, 2, 3])
        entries["bad.txt"] = Data([0xff])
        entries[".git/config"] = Data("git".utf8)
        entries["large.txt"] = Data(repeating: 65, count: 512 * 1_024 + 1)
        let files = ProjectImportFilter.select(entries, report: &report)
        XCTAssertEqual(Set(files.keys), Set(paths))
        XCTAssertEqual(report.omissionCount, 4)
        XCTAssertEqual(Set(report.omissions.map(\.path)), ["assets/logo.png", "bad.txt", ".git/config", "large.txt"])
        XCTAssertTrue(report.isPartial)
        XCTAssertEqual(try JSONDecoder().decode(ProjectImportReport.self, from: JSONEncoder().encode(report)), report)
    }

    func testBudgetOmissionsAndArchiveOriginSurviveDocumentExport() throws {
        var report = ProjectImportReport()
        let files = ProjectImportFilter.select(["main.go": Data("package main".utf8), "go.mod": Data("module m".utf8), "notes.txt": Data("notes".utf8)], report: &report, maximumFiles: 2)
        XCTAssertEqual(report.reasons["Snapshot file limit"], 1)
        let archive = try ProjectArchive.gzip(ProjectArchive.tar(files: files, root: "m"))
        let sha = String(repeating: "a", count: 40)
        let imported = try GitHubRepositoryImporter().project(fromArchive: archive, reference: GitHubRepositoryReference(owner: "owner", repository: "m", reference: "moving"), importedAt: Date(timeIntervalSince1970: 1_000), commit: sha)
        XCTAssertEqual(imported.provenance?.commit, sha)
        XCTAssertEqual(imported.provenance?.importReport?.archiveSHA256, ProjectImportReport.digest(archive))
        let copy = try JSONDecoder.gopherForge.decode(GopherForgeProject.self, from: JSONEncoder.gopherForge.encode(imported))
        XCTAssertEqual(copy.provenance, imported.provenance)
    }

    func testLocalSnapshotDoesNotFollowSymlinksOrMangleInvalidUTF8() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "import-inventory-\(UUID())")
        let outside = FileManager.default.temporaryDirectory.appending(path: "outside-\(UUID()).txt")
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("package main".utf8).write(to: root.appending(path: "main.go"))
        try Data([0xff, 0xfe]).write(to: root.appending(path: "bad.txt"))
        try Data("private outside".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "linked.txt"), withDestinationURL: outside)
        let imported = try LocalProjectLoader().load(from: root)
        XCTAssertNil(imported.files["bad.txt"])
        XCTAssertNil(imported.files["linked.txt"])
        XCTAssertEqual(imported.provenance?.importReport?.omissionCount, 2)
        XCTAssertEqual(try Data(contentsOf: outside), Data("private outside".utf8))
    }

    func testArchiveNonregularEntriesAreInventoriedAndDuplicatePathsRefused() throws {
        var tar = try ProjectArchive.tar(files: ["link.txt": ""], root: "root")
        tar[156] = UInt8(ascii: "2")
        var report = ProjectImportReport()
        XCTAssertTrue(try ProjectArchive.entries(fromTar: tar, report: &report).isEmpty)
        XCTAssertEqual(report.omissionCount, 1)
        let one = try ProjectArchive.tar(files: ["main.go": "package main"], root: "root")
        var duplicate = Data(one.dropLast(1_024)); duplicate.append(one)
        XCTAssertThrowsError(try ProjectArchive.entries(fromTar: duplicate))
    }

    func testNetworkResolvesBranchThenDownloadsOnlyTheFixedCommit() async throws {
        let sha = String(repeating: "b", count: 40)
        let archive = try ProjectArchive.gzip(ProjectArchive.tar(files: ["main.go": "package main"], root: "repo-" + sha))
        ImportURLProtocol.configure { request in
            if request.url?.host == "api.github.com" {
                XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "sha" }?.value, "feature/work")
                return (Data("[{\"sha\":\"\(sha)\"}]".utf8), 200)
            }
            XCTAssertEqual(request.url?.host, "codeload.github.com")
            XCTAssertEqual(request.url?.path, "/owner/repo/tar.gz/" + sha)
            return (archive, 200)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ImportURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let project = try await GitHubRepositoryImporter(session: session).importRepository(GitHubRepositoryReference(owner: "owner", repository: "repo", reference: "feature/work"))
        XCTAssertEqual(project.provenance?.commit, sha)
        XCTAssertEqual(project.provenance?.reference, "feature/work")
        XCTAssertEqual(ImportURLProtocol.requestCount, 2)
    }

    func testLegacyUnpinnedProvenanceDoesNotRestoreSourceFromAMovingBranch() throws {
        let old = GopherForgeProject.Provenance(source: .github, owner: "owner", repository: "repo", reference: "main", commit: nil, importedAt: Date(timeIntervalSince1970: 1_000))
        let encoded = try JSONEncoder.gopherForge.encode(old)
        let decoded = try JSONDecoder.gopherForge.decode(GopherForgeProject.Provenance.self, from: encoded)
        XCTAssertNil(decoded.importReport)
        XCTAssertNil(decoded.pinnedGitHubReference)
        var pinnedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        pinnedJSON["commit"] = String(repeating: "a", count: 40)
        let pinned = try JSONDecoder.gopherForge.decode(GopherForgeProject.Provenance.self, from: JSONSerialization.data(withJSONObject: pinnedJSON))
        XCTAssertEqual(pinned.pinnedGitHubReference?.reference, String(repeating: "a", count: 40))
    }

    func testUnresolvedRevisionNeverFallsBackToAMovingArchive() async throws {
        ImportURLProtocol.configure { _ in (Data("[]".utf8), 200) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ImportURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        do {
            _ = try await GitHubRepositoryImporter(session: session).importRepository(GitHubRepositoryReference(owner: "owner", repository: "repo", reference: nil))
            XCTFail("must fail closed without an immutable commit")
        } catch { }
        XCTAssertEqual(ImportURLProtocol.requestCount, 1)
    }
}

private final class ImportURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> (Data, Int))?
    nonisolated(unsafe) private static var count = 0
    static var requestCount: Int { lock.withLock { count } }
    static func configure(_ body: @escaping (URLRequest) throws -> (Data, Int)) { lock.withLock { handler = body; count = 0 } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = Self.lock.withLock { Self.count += 1; return Self.handler }
            let (data, status) = try XCTUnwrap(handler)(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "\(data.count)"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
