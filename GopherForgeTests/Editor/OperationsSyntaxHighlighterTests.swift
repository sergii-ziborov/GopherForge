import XCTest
@testable import GopherForge

final class OperationsSyntaxHighlighterTests: XCTestCase {
    func testShellProtectsQuotedHashesAndHighlightsArguments() {
        let source = "# comment with a quote \"\ncurl --max-time 5 \"$url#anchor\"\nprintf '%s' \"$name\"\n"
        let tokens = SourceFileKind.shell.tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .comment && source[$0.range] == "# comment with a quote \"" })
        XCTAssertTrue(tokens.contains { $0.kind == .function && source[$0.range] == "curl" })
        XCTAssertTrue(tokens.contains { $0.kind == .directive && source[$0.range] == "--max-time" })
        XCTAssertTrue(tokens.contains { $0.kind == .string && source[$0.range] == "\"$url#anchor\"" })
        XCTAssertFalse(tokens.contains { $0.kind == .comment && source[$0.range].contains("anchor") })
        for pair in zip(tokens, tokens.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.range.upperBound, pair.1.range.lowerBound)
        }
    }

    func testManifestKeysAndDockerfileInstructionsUseTheirOwnLanguage() {
        let yaml = "replicas: 2\n  image: go-api:dev\n  ready: true\n"
        let tokens = SourceFileKind.yaml.tokens(in: yaml)
        XCTAssertTrue(tokens.contains { $0.kind == .directive && yaml[$0.range] == "image" })
        XCTAssertTrue(tokens.contains { $0.kind == .number && yaml[$0.range] == "2" })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && yaml[$0.range] == "true" })
        let docker = "FROM golang:1.27 AS build\nCOPY --from=build /out/api /api\n"
        let build = SourceFileKind.dockerfile.tokens(in: docker)
        XCTAssertTrue(build.contains { $0.kind == .keyword && docker[$0.range] == "FROM" })
        XCTAssertTrue(build.contains { $0.kind == .directive && docker[$0.range] == "--from" })
        XCTAssertEqual(SourceFileKind.of(path: "scripts/test.sh"), .shell)
        XCTAssertEqual(SourceFileKind.of(path: "deploy/api.yaml"), .yaml)
        XCTAssertEqual(SourceFileKind.of(path: "compose.yml"), .yaml)
        XCTAssertEqual(SourceFileKind.of(path: "Dockerfile"), .dockerfile)
        XCTAssertEqual(SourceFileKind.of(path: "Containerfile"), .dockerfile)
    }
}
