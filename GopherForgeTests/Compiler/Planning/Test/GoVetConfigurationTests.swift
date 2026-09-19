import XCTest
@testable import GopherForge

final class GoVetConfigurationTests: XCTestCase {
    func testTheWireNamesAreWhatCmdVetExports() throws {
        let configuration = GoVetConfiguration(
            importPath: "example.com/forge",
            directory: "/work",
            goFiles: ["/work/main.go"],
            archives: ["example.com/forge": "/tmp/forge.a"],
            standardLibrary: ["fmt"],
            factsOutput: "/tmp/forge.vetx"
        )
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(configuration.encoded().utf8)) as? [String: Any]
        )
        XCTAssertEqual(json["ID"] as? String, "example.com/forge")
        XCTAssertEqual(json["Compiler"] as? String, "gc")
        XCTAssertEqual(json["ImportPath"] as? String, "example.com/forge")
        XCTAssertEqual(json["VetxOutput"] as? String, "/tmp/forge.vetx")
        XCTAssertEqual(json["SucceedOnTypecheckFailure"] as? Bool, false)
        let packageFile = try XCTUnwrap(json["PackageFile"] as? [String: String])
        XCTAssertEqual(packageFile["fmt"], GoGuestPath.standardLibraryArchive(for: "fmt"))
        XCTAssertEqual(packageFile["example.com/forge"], "/tmp/forge.a")
        let importMap = try XCTUnwrap(json["ImportMap"] as? [String: String])
        XCTAssertEqual(importMap["fmt"], "fmt")
    }

    func testEncodedJSONIsStableEnoughToHash() {
        let configuration = GoVetConfiguration(
            importPath: "p",
            directory: "/work",
            goFiles: ["a.go"],
            archives: [:],
            standardLibrary: ["fmt", "os"],
            factsOutput: "/tmp/x"
        )
        XCTAssertEqual(configuration.encoded(), configuration.encoded())
        XCTAssertTrue(configuration.encoded().contains("\"Compiler\":\"gc\""))
    }
}
