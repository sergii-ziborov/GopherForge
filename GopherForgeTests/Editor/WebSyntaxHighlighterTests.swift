import XCTest
@testable import GopherForge

final class WebSyntaxHighlighterTests: XCTestCase {
    func testHTMLColoursTagsAttributesAndComments() {
        let source = """
        <!-- café -->
        <a href="/about" class="nav">About</a>
        """
        let tokens = HTMLSyntaxHighlighter().tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .comment && source[$0.range].contains("café") })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "a" })
        XCTAssertTrue(tokens.contains { $0.kind == .package && source[$0.range] == "href" })
        XCTAssertTrue(tokens.contains { $0.kind == .string && source[$0.range] == "\"/about\"" })
    }

    func testAnUnterminatedHTMLCommentDoesNotThrow() {
        let tokens = HTMLSyntaxHighlighter().tokens(in: "<!-- still typing")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testJavaScriptColoursKeywordsStringsAndFunctions() {
        let source = """
        const greetings = ["hi"];
        function next() { return greetings[0]; }
        // pin
        """
        let tokens = JavaScriptSyntaxHighlighter().tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "const" })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "function" })
        XCTAssertTrue(tokens.contains { $0.kind == .function && source[$0.range] == "next" })
        XCTAssertTrue(tokens.contains { $0.kind == .string && source[$0.range] == "\"hi\"" })
        XCTAssertTrue(tokens.contains { $0.kind == .comment && source[$0.range].contains("pin") })
    }

    func testJavaScriptBlockCommentsAndTemplateStrings() {
        let source = "/* note */ const x = `hello`;"
        let tokens = JavaScriptSyntaxHighlighter().tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .comment && source[$0.range] == "/* note */" })
        XCTAssertTrue(tokens.contains { $0.kind == .string && source[$0.range] == "`hello`" })
    }

    func testCSSColoursRulesPropertiesAndColours() {
        let source = """
        /* paper */
        @media screen {
          body { color: #c45c26; width: 32rem; }
        }
        """
        let tokens = CSSSyntaxHighlighter().tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .comment })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "@media" })
        XCTAssertTrue(tokens.contains { $0.kind == .directive && source[$0.range] == "color" })
        XCTAssertTrue(tokens.contains { $0.kind == .type && source[$0.range] == "body" })
        XCTAssertTrue(tokens.contains { $0.kind == .number && source[$0.range] == "#c45c26" })
    }

    func testJSONColoursStringsNumbersAndWords() {
        let source = #"{"ok":true,"count":3,"empty":null}"#
        let tokens = JSONSyntaxHighlighter().tokens(in: source)
        XCTAssertTrue(tokens.contains { $0.kind == .string && source[$0.range] == "\"ok\"" })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "true" })
        XCTAssertTrue(tokens.contains { $0.kind == .number && source[$0.range] == "3" })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && source[$0.range] == "null" })
    }

    func testKindsFollowWebFileNames() {
        XCTAssertEqual(SourceFileKind.of(path: "web/index.html"), .html)
        XCTAssertEqual(SourceFileKind.of(path: "page.htm"), .html)
        XCTAssertEqual(SourceFileKind.of(path: "web/app.js"), .javascript)
        XCTAssertEqual(SourceFileKind.of(path: "mod.mjs"), .javascript)
        XCTAssertEqual(SourceFileKind.of(path: "web/styles.css"), .css)
        XCTAssertEqual(SourceFileKind.of(path: "web/api/health.json"), .json)
        XCTAssertFalse(SourceFileKind.html.tokens(in: "<p class=\"x\"></p>").isEmpty)
        XCTAssertFalse(SourceFileKind.javascript.tokens(in: "const x = 1;").isEmpty)
        XCTAssertFalse(SourceFileKind.css.tokens(in: "p { color: red; }").isEmpty)
        XCTAssertFalse(SourceFileKind.json.tokens(in: #"{"a":1}"#).isEmpty)
    }
}
