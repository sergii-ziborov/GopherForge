import XCTest
@testable import GopherForge

final class GoModuleDownloadTests: XCTestCase {
    func testUppercaseModuleInstallsWithVerifiedOriginalCaseSources() async throws {
        let reference = GoModuleReference(path: "github.com/BurntSushi/toml", version: "v1.4.0")
        let source = [
            reference.archivePrefix + "go.mod": Data("module \(reference.path)\n\ngo 1.18\n".utf8),
            reference.archivePrefix + "toml.go": Data("package toml\nfunc Answer() int { return 42 }\n".utf8),
        ]
        let hash = try GoModuleHash.hash1(files: source)
        let transport = ModuleResponseTransport(responses: [
            "/github.com/!burnt!sushi/toml/@v/v1.4.0.zip": try ZipArchive.data(from: source),
            "/lookup/github.com/!burnt!sushi/toml@v1.4.0": Data("""
            1
            \(reference.path) \(reference.version) \(hash)
            \(reference.path) \(reference.version)/go.mod h1:fixture=
            """.utf8),
        ])
        let installer = GoPackageInstaller(
            proxy: GoModuleProxyClient(transport: transport),
            checksums: GoChecksumDatabase(transport: transport)
        )
        let result = try await installer.install(
            path: reference.path, version: reference.version,
            into: ["go.mod": "module example.com/app\n\ngo 1.18\n"]
        )
        XCTAssertEqual(result.verifiedHash, hash)
        XCTAssertNotNil(result.files["vendor/github.com/BurntSushi/toml/toml.go"])
        XCTAssertTrue(result.files["go.sum"]?.contains("github.com/BurntSushi/toml v1.4.0") == true)
    }

    func testUppercaseVersionIsEscapedForArchiveModAndChecksumRequests() async throws {
        let reference = GoModuleReference(path: "example.com/module", version: "v1.0.0-RC1")
        let transport = ModuleResponseTransport(responses: [
            "/example.com/module/@v/v1.0.0-!r!c1.zip": Data(),
            "/example.com/module/@v/v1.0.0-!r!c1.mod": Data("module example.com/module".utf8),
            "/lookup/example.com/module@v1.0.0-!r!c1": Data("""
            1
            example.com/module v1.0.0-RC1 h1:module=
            example.com/module v1.0.0-RC1/go.mod h1:mod=
            """.utf8),
        ])
        let proxy = GoModuleProxyClient(transport: transport)
        _ = try await proxy.archive(for: reference)
        _ = try await proxy.goModFile(for: reference)
        _ = try await GoChecksumDatabase(transport: transport).record(for: reference)
    }

    func testDownloadFailuresDoNotMisreportAnAvailableNetwork() {
        let errors: [any Error] = [
            GoModuleArchive.ArchiveError.tooManyFiles(4_001),
            GoModuleArchive.ArchiveError.unreadable,
            GoModuleArchive.ArchiveError.emptyModule,
            GoModuleProxyClient.ProxyError.badStatus(400, "module"),
            GoModuleProxyClient.ProxyError.malformedResponse("latest"),
            GoChecksumDatabase.ChecksumError.badStatus(403),
            GoChecksumDatabase.ChecksumError.noHashInResponse("module"),
        ]
        for error in errors {
            let detail = GoDependencyPreparer.describe(error, path: "example.com/module")
            XCTAssertFalse(detail.contains("needs a network"), "\(error): \(detail)")
            XCTAssertFalse(detail.contains("Could not reach"), "\(error): \(detail)")
        }
        XCTAssertTrue(GoDependencyPreparer.describe(
            GoChecksumDatabase.ChecksumError.badStatus(403), path: "module"
        ).contains("403"))
    }
}

private struct ModuleResponseTransport: GoHTTPTransport {
    let responses: [String: Data]

    func get(_ url: URL, limit: Int) async throws -> (Data, Int) {
        guard let data = responses[url.path] else {
            XCTFail("Unexpected module request: \(url.absoluteString)")
            return (Data(), 400)
        }
        XCTAssertLessThanOrEqual(data.count, limit)
        return (data, 200)
    }
}

/// Opt-in integration check against the official services, run on an iPhone simulator.
final class GoModuleLiveDownloadTests: XCTestCase {
    @MainActor
    func testStartupDownloadsVerifyAndReloadAfterCleanup() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GOPHERFORGE_RUN_NETWORK_TESTS"] == "1")
        let references = [
            GoModuleReference(path: "github.com/BurntSushi/toml", version: "v1.4.0"),
            GoModuleReference(path: "github.com/Masterminds/semver/v3", version: "v3.3.0"),
        ]
        let original = GopherForgeProject(name: "Network check", files: [
            "go.mod": "module example.com/networkcheck\n\ngo 1.18\nrequire (\n"
                + references.map { "\t\($0.path) \($0.version)\n" }.joined() + ")\n",
            "main.go": "package main\nfunc main() {}\n",
        ], entryFile: "main.go", provenance: .files())
        let preparer = GoDependencyPreparer(
            planError: { files, skipping in
                references.first { reference in
                    !skipping.contains(reference.path)
                        && !files.keys.contains { $0.hasPrefix("vendor/\(reference.path)/") }
                }.map { .unresolvedImport($0.path, importedBy: "example.com/networkcheck") }
            },
            install: { path, version, importPath, files in
                try await GoPackageInstaller().install(path: path, version: version,
                    into: files, neededImport: importPath).files
            }
        )
        let first = try await preparer.prepare(files: original.files)
        XCTAssertEqual(first.installed.count, 2)
        XCTAssertTrue(first.problems.isEmpty, "\(first.problems)")
        let cleaned = GoPackageStorage.clearingDownloadedPackages(from: original.replacingFiles(first.files))
        XCTAssertGreaterThan(cleaned.summary.fileCount, 0)
        let second = try await preparer.prepare(files: cleaned.project.files)
        XCTAssertEqual(second.installed.count, 2)
        XCTAssertTrue(second.problems.isEmpty, "\(second.problems)")
        XCTAssertEqual(second.files, first.files)
    }
}

/// The parts of installing a package that must be exactly right, checked
/// without a network.
///
/// The hash vector below is the important one: it was produced by the algorithm
/// as Go specifies it, and that implementation was first checked against a real
/// published `go.sum` hash. If this test passes, the app computes the same
/// module hash Go does — which is the whole basis for refusing a bad download.
final class GoModuleHashTests: XCTestCase {
    /// `example.com/tiny@v1.0.0` holding three files. Value produced by
    /// dirhash.Hash1 over the same names and bytes.
    func testHashMatchesGosOwnAlgorithm() throws {
        let files: [String: Data] = [
            "example.com/tiny@v1.0.0/go.mod": Data("module example.com/tiny\n\ngo 1.24\n".utf8),
            "example.com/tiny@v1.0.0/tiny.go": Data("package tiny\n\nfunc Answer() int { return 42 }\n".utf8),
            "example.com/tiny@v1.0.0/LICENSE": Data("MIT\n".utf8),
        ]

        XCTAssertEqual(
            try GoModuleHash.hash1(files: files),
            "h1:MX1+3ZScKiNvQRVULT5GnBvjTTIGcxG6nTHMuJiKe2c="
        )
    }

    /// Order must not matter to the caller, because it does not to Go: the
    /// names are sorted before hashing.
    func testHashDoesNotDependOnDictionaryOrder() throws {
        let a = try GoModuleHash.hash1(files: [
            "m@v1/a.go": Data("a".utf8), "m@v1/b.go": Data("b".utf8), "m@v1/c.go": Data("c".utf8),
        ])
        let b = try GoModuleHash.hash1(files: [
            "m@v1/c.go": Data("c".utf8), "m@v1/a.go": Data("a".utf8), "m@v1/b.go": Data("b".utf8),
        ])
        XCTAssertEqual(a, b)
    }

    func testOneChangedByteChangesTheHash() throws {
        let original = try GoModuleHash.hash1(files: ["m@v1/a.go": Data("package a".utf8)])
        let tampered = try GoModuleHash.hash1(files: ["m@v1/a.go": Data("package b".utf8)])
        XCTAssertNotEqual(original, tampered)
    }

    /// Go refuses these, and so must this: a newline in a name would make the
    /// summary ambiguous, and an ambiguous summary is forgeable.
    func testANameWithANewlineIsRefused() {
        XCTAssertThrowsError(try GoModuleHash.hash1(files: ["m@v1/a\nb.go": Data()]))
    }
}

/// Module references, versions, and the checksum database's wire format.
final class GoModuleReferenceTests: XCTestCase {
    func testAValidReferenceIsAccepted() {
        let reference = GoModuleReference.validated(path: "github.com/google/uuid", version: "v1.6.0")
        XCTAssertEqual(reference?.archivePrefix, "github.com/google/uuid@v1.6.0/")
    }

    /// The path becomes a URL and then a directory name, so traversal has to be
    /// impossible before anything is fetched.
    func testTraversalAndNonsenseAreRefused() {
        XCTAssertNil(GoModuleReference.validated(path: "github.com/../etc", version: "v1.0.0"))
        XCTAssertNil(GoModuleReference.validated(path: "/absolute/path", version: "v1.0.0"))
        XCTAssertNil(GoModuleReference.validated(path: "nodot/x", version: "v1.0.0"))
        XCTAssertNil(GoModuleReference.validated(path: "single", version: "v1.0.0"))
        XCTAssertNil(GoModuleReference.validated(path: "a.com/b", version: "1.0.0"))
        XCTAssertNil(GoModuleReference.validated(path: "a.com/b", version: "latest"))
    }

    func testVersionsSortNewestFirstWithPreReleasesBelowTheirRelease() {
        XCTAssertEqual(
            GoSemanticVersion.sortedNewestFirst(
                ["v1.2.0", "v1.10.0", "v1.2.0-rc.1", "v0.9.0", "v2.0.0"]
            ),
            ["v2.0.0", "v1.10.0", "v1.2.0", "v1.2.0-rc.1", "v0.9.0"]
        )
    }

    func testNewestStableIgnoresPreReleases() {
        XCTAssertEqual(
            GoSemanticVersion.newestStable(["v1.9.4", "v2.0.0-rc.1"]),
            "v1.9.4"
        )
        XCTAssertEqual(
            GoSemanticVersion.newestStable(["v2.0.0-rc.1"]),
            "v2.0.0-rc.1",
            "with nothing stable, the pre-release is all there is"
        )
    }

    func testChecksumLookupIsParsedIntoBothHashes() throws {
        let reference = GoModuleReference(path: "github.com/google/uuid", version: "v1.6.0")
        let response = """
        22152757
        github.com/google/uuid v1.6.0 h1:NIvaJDMOsjHA8n1jAhLSgzrAzy1Hgr+hNrb57e+94F0=
        github.com/google/uuid v1.6.0/go.mod h1:TIyPZe4MgqvfeYDBFedMoGGpEw/LqOeaOT+nhxU+yHo=

        go.sum database tree
        """

        let record = try GoChecksumDatabase.parse(response, for: reference)
        XCTAssertEqual(record.moduleHash, "h1:NIvaJDMOsjHA8n1jAhLSgzrAzy1Hgr+hNrb57e+94F0=")
        XCTAssertTrue(record.goModHash.hasPrefix("h1:TIyPZe4"))

        XCTAssertEqual(
            GoChecksumDatabase.goSumLines(for: reference, record: record),
            """
            github.com/google/uuid v1.6.0 h1:NIvaJDMOsjHA8n1jAhLSgzrAzy1Hgr+hNrb57e+94F0=
            github.com/google/uuid v1.6.0/go.mod h1:TIyPZe4MgqvfeYDBFedMoGGpEw/LqOeaOT+nhxU+yHo=

            """
        )
    }

    /// A response about a different module must never be accepted for this one.
    func testALookupForAnotherModuleIsNotAccepted() {
        let reference = GoModuleReference(path: "github.com/google/uuid", version: "v1.6.0")
        let response = """
        1
        github.com/attacker/evil v1.6.0 h1:AAAA=
        github.com/attacker/evil v1.6.0/go.mod h1:BBBB=
        """
        XCTAssertThrowsError(try GoChecksumDatabase.parse(response, for: reference))
    }
}
