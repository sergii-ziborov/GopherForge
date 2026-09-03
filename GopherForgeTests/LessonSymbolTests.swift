import UIKit
import XCTest
@testable import GopherForge

/// The lesson icons, which are only worth drawing if they differ.
final class LessonSymbolTests: XCTestCase {
    /// A name with a typo in it renders as nothing at all, and nothing at all
    /// looks like a deliberately blank row.
    func testEverySymbolIsARealSystemImage() {
        for (concept, symbol) in LessonSymbol.byConcept {
            XCTAssertNotNil(
                UIImage(systemName: symbol),
                "\(concept) uses \(symbol), which is not a system image"
            )
        }
    }

    /// The defect this was written for: the symbol was picked by whether the
    /// lesson needed the compiler, and most lessons do — so a unit was a column
    /// of identical hammers.
    func testAUnitDoesNotShowTheSameSymbolOnEveryLesson() {
        for unit in GoCourseCatalog.units where unit.teachingLessons.count > 2 {
            let symbols = Set(unit.teachingLessons.map(LessonSymbol.symbol(for:)))
            XCTAssertGreaterThan(
                symbols.count, 1,
                "every lesson in \(unit.id) shows \(symbols.first ?? "the same symbol")"
            )
        }
    }

    func testEveryTaughtConceptHasASymbol() {
        let missing = GoCourseCatalog.taughtConcepts
            .subtracting(LessonSymbol.byConcept.keys)
        XCTAssertTrue(missing.isEmpty, "concepts with no symbol: \(missing.sorted())")
    }
}
