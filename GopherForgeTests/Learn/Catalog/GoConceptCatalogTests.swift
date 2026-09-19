import XCTest
@testable import GopherForge

final class GoConceptCatalogTests: XCTestCase {
    func testTheSharedVocabularyHasNoDuplicates() {
        XCTAssertEqual(GoConcept.all.count, Set(GoConcept.all).count)
        XCTAssertTrue(GoConcept.all.contains(GoConcept.undefinedSymbol))
        XCTAssertTrue(GoConcept.all.contains(GoConcept.varsUnused))
        XCTAssertTrue(GoConcept.all.contains(GoConcept.deadlock))
        XCTAssertFalse(GoConcept.all.contains(""))
    }

    func testTheTaggerOnlyEmitsKnownConcepts() {
        let messages = [
            "declared and not used: x",
            "imported and not used: fmt",
            "undefined: Y",
            "missing return",
            "no new variables on left side of :=",
            "assignment mismatch",
            "does not implement Writer",
            "cannot use x as type string",
            "all goroutines are asleep",
            "send on closed channel",
            "close of closed channel",
            "assignment to entry in nil map",
            "index out of range [3]",
            "invalid memory address or nil pointer dereference",
            "something the tagger has never seen",
        ]
        for message in messages {
            if let tag = GoConceptTagger.tag(for: message) {
                XCTAssertTrue(GoConcept.all.contains(tag), "\(message) -> \(tag)")
            }
        }
        XCTAssertNil(GoConceptTagger.tag(for: "something the tagger has never seen"))
        XCTAssertEqual(GoConceptTagger.tag(for: "Undefined: X"), GoConcept.undefinedSymbol)
    }
}
