import XCTest
@testable import GopherForge

final class GoConceptTaggerTests: XCTestCase {
    func testAnchoredUnusedVariable() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "declared and not used: total"),
            GoConcept.varsUnused
        )
        XCTAssertNil(
            GoConceptTagger.tag(for: "note: declared and not used: total"),
            "the unused-var wording is only tagged at the start of the message"
        )
    }

    func testAnchoredUnusedImport() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "imported and not used: \"fmt\""),
            GoConcept.unusedImport
        )
    }

    func testAnchoredUndefined() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "undefined: fmt"),
            GoConcept.undefinedSymbol
        )
    }

    func testMissingReturn() {
        XCTAssertEqual(GoConceptTagger.tag(for: "missing return"), GoConcept.missingReturn)
    }

    func testShortDeclaration() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "no new variables on left side of :="),
            GoConcept.shortDeclaration
        )
    }

    func testAssignmentMismatch() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "assignment mismatch: 1 variable but foo returns 2 values"),
            GoConcept.explicitErrorCheck
        )
    }

    func testMethodSet() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "Handler does not implement http.Handler"),
            GoConcept.methodSet
        )
    }

    func testTypeAssignment() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "cannot use x (variable of type int) as string"),
            GoConcept.typeAssignment
        )
    }

    func testRuntimeSignatures() {
        XCTAssertEqual(
            GoConceptTagger.tag(for: "all goroutines are asleep - deadlock!"),
            GoConcept.deadlock
        )
        XCTAssertEqual(
            GoConceptTagger.tag(for: "send on closed channel"),
            GoConcept.channelClose
        )
        XCTAssertEqual(
            GoConceptTagger.tag(for: "close of closed channel"),
            GoConcept.channelClose
        )
        XCTAssertEqual(
            GoConceptTagger.tag(for: "assignment to entry in nil map"),
            GoConcept.mapZeroValue
        )
        XCTAssertEqual(
            GoConceptTagger.tag(for: "runtime error: index out of range"),
            GoConcept.sliceBounds
        )
        XCTAssertEqual(
            GoConceptTagger.tag(for: "invalid memory address or nil pointer dereference"),
            GoConcept.nilInterface
        )
    }

    func testAnUnknownMessageStaysUntagged() {
        XCTAssertNil(GoConceptTagger.tag(for: "too many arguments in call to fmt.Println"))
        XCTAssertNil(GoConceptTagger.tag(for: ""))
    }
}
