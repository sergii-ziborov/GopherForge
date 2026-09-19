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

    func testRejectsAUserPageWithNoRepository() {
        XCTAssertThrowsError(try GitHubRepositoryReference.parse("https://github.com/golang")) { error in
            XCTAssertEqual(error as? GitHubRepositoryReference.ParseError, .missingRepository)
        }
    }
}
