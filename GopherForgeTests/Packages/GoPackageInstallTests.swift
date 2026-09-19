import XCTest
@testable import GopherForge

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
