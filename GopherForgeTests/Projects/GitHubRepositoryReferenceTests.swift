import XCTest
@testable import GopherForge

final class GitHubRepositoryReferenceTests: XCTestCase {
    func testParsesOwnerAndRepository() throws {
        let reference = try GitHubRepositoryReference.parse("https://github.com/golang/tools")
        XCTAssertEqual(reference.owner, "golang")
        XCTAssertEqual(reference.repository, "tools")
        XCTAssertNil(reference.reference)
    }

    func testParsesBranchFromATreeURL() throws {
        let reference = try GitHubRepositoryReference.parse("https://github.com/golang/tools/tree/master")
        XCTAssertEqual(reference.reference, "master")
    }

    func testDropsTheGitSuffix() throws {
        let reference = try GitHubRepositoryReference.parse("https://github.com/golang/tools.git")
        XCTAssertEqual(reference.repository, "tools")
    }

    func testRejectsOtherHosts() {
        XCTAssertThrowsError(try GitHubRepositoryReference.parse("https://gitlab.com/a/b")) { error in
            XCTAssertEqual(error as? GitHubRepositoryReference.ParseError, .notGitHub)
        }
    }

    func testFindsARepositoryLinkInsideSharedText() throws {
        let reference = try GitHubRepositoryReference.parse(
            "Look at this https://github.com/usememos/memos and tell me what you think"
        )
        XCTAssertEqual(reference.displayName, "usememos/memos")
        XCTAssertNil(reference.reference)
    }

    func testATreeLinkInsideTextKeepsTheBranch() throws {
        let reference = try GitHubRepositoryReference.parse(
            "Branch: https://github.com/golang/tools/tree/master/cmd"
        )
        XCTAssertEqual(reference.owner, "golang")
        XCTAssertEqual(reference.repository, "tools")
        XCTAssertEqual(reference.reference, "master/cmd")
    }

    func testAnImportLinkCarriesTheRepositoryURL() throws {
        let url = try XCTUnwrap(
            GopherForgeLink.importURL(repository: "https://github.com/usememos/memos")
        )
        XCTAssertEqual(url.scheme, "gopherforge")
        XCTAssertEqual(
            GopherForgeLink.repositoryURL(from: url),
            "https://github.com/usememos/memos"
        )
        XCTAssertNil(GopherForgeLink.repositoryURL(from: URL(string: "https://github.com/usememos/memos")!))
    }

    func testRejectsAUserPageWithNoRepository() {
        XCTAssertThrowsError(try GitHubRepositoryReference.parse("https://github.com/golang")) { error in
            XCTAssertEqual(error as? GitHubRepositoryReference.ParseError, .missingRepository)
        }
    }
}
