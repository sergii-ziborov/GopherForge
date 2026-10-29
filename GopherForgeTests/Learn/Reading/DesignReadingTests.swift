import XCTest
@testable import GopherForge

final class DesignReadingTests: XCTestCase {
    private let unitCounts = ["architecture": 19, "clean-code": 8,
        "patterns-creational": 5, "patterns-structural": 7,
        "patterns-behavioral": 11, "patterns-go": 6]

    func testDesignCoverageAndStableExistingLessonIDs() throws {
        for (id, count) in unitCounts {
            let unit = try XCTUnwrap(GoCourseCatalog.unit(id: id))
            XCTAssertEqual(unit.teachingLessons.count, count, id)
            XCTAssertTrue(unit.lessons.allSatisfy { !$0.requiresCompiler }, id)
        }
        for id in ["architecture.package-boundaries", "architecture.ports-and-adapters",
                   "architecture.styles-and-clean-code"] {
            XCTAssertEqual(GoCourseCatalog.unit(containing: id)?.id, "architecture")
        }
        let classic = ["factory-method", "abstract-factory", "builder", "prototype", "singleton",
            "adapter", "bridge", "composite", "decorator", "facade", "flyweight", "proxy",
            "strategy", "command", "chain", "iterator", "mediator", "memento", "observer",
            "state", "template-method", "visitor", "interpreter"]
        for name in classic {
            XCTAssertNotNil(ReadingLessonCatalog.reading(for: "patterns.\(name)"), name)
        }
        XCTAssertEqual(classic.count, 23)
    }

    func testRatingsUseTheSameScenariosAndDiagramsExplainTradeoffs() throws {
        let scenarios = ["Small tool or CLI", "Domain-rich application", "Independent distributed services"]
        let readings = ReadingLessonCatalog.all.filter { unitCounts[$0.unitID] != nil }
        XCTAssertEqual(readings.count, 56)
        for reading in readings {
            let guide = try XCTUnwrap(reading.designGuide, reading.id)
            XCTAssertGreaterThanOrEqual(guide.flow.count, 3, reading.id)
            XCTAssertTrue(guide.flow.allSatisfy { !$0.isEmpty }, reading.id)
            XCTAssertGreaterThanOrEqual(guide.strengths.count, 2, reading.id)
            XCTAssertGreaterThanOrEqual(guide.cautions.count, 2, reading.id)
            XCTAssertFalse(guide.cost.isEmpty, reading.id)
            if !guide.ratings.isEmpty {
                XCTAssertEqual(guide.ratings.map(\.scenario), scenarios, reading.id)
                XCTAssertTrue(guide.ratings.allSatisfy { (1...5).contains($0.score) }, reading.id)
            }
        }
        let rated = readings.filter { $0.unitID == "architecture" && !($0.designGuide?.ratings.isEmpty ?? true) }
        XCTAssertEqual(rated.count, 17, "Each covered style needs all three comparable scores")
        let simple = try XCTUnwrap(ReadingLessonCatalog.reading(for: "architecture.simple-monolith")?.designGuide)
        let micro = try XCTUnwrap(ReadingLessonCatalog.reading(for: "architecture.microservices")?.designGuide)
        XCTAssertGreaterThan(simple.ratings[0].score, micro.ratings[0].score)
        XCTAssertLessThan(simple.ratings[2].score, micro.ratings[2].score)
    }

    func testEveryDesignLessonFeedsMatchingAndThreeAnswerMistakeReview() throws {
        for reading in ReadingLessonCatalog.all where unitCounts[reading.unitID] != nil {
            let pair = try XCTUnwrap(ReviewMatchCatalog.allPairs.first { $0.requiredLessonID == reading.id })
            XCTAssertEqual(pair.prompt, reading.reviewPrompt)
            XCTAssertEqual(pair.answer, reading.reviewAnswer)
            XCTAssertLessThanOrEqual(pair.prompt.count, MatchingDrill.maximumPromptCharacters)
            XCTAssertLessThanOrEqual(pair.answer.count, MatchingDrill.maximumAnswerCharacters)
            XCTAssertEqual(reading.wrongAnswers.count, 2)
            XCTAssertEqual(Set([reading.reviewAnswer] + reading.wrongAnswers).count, 3)
            XCTAssertTrue(GoConcept.all.contains(reading.conceptTag))
            XCTAssertNotNil(MistakeReviewCatalog.all.first { $0.id == "reading.question.\(reading.id)" })
        }
    }

    func testNewExamplesAreCompleteProgramsWithDocumentedOutput() {
        let programs = ReadingLessonCatalog.all.filter { unitCounts[$0.unitID] != nil }.flatMap { reading in
            reading.sections.compactMap { section -> String? in
                guard let code = section.code, code.contains("// Output:\n") else { return nil }
                XCTAssertEqual(section.language, "go", reading.id)
                XCTAssertTrue(code.hasPrefix("package main\n"), reading.id)
                XCTAssertTrue(code.contains("func main()"), reading.id)
                return code
            }
        }
        XCTAssertEqual(programs.count, 53)
    }

    func testLearningOnePatternDoesNotUnlockUnstudiedPatterns() throws {
        let strategy = try XCTUnwrap(ReadingLessonCatalog.reading(for: "patterns.strategy"))
        let visitor = try XCTUnwrap(ReadingLessonCatalog.reading(for: "patterns.visitor"))
        XCTAssertNotEqual(strategy.conceptTag, visitor.conceptTag)
        let pairs = ReviewMatchCatalog.unlocked(completed: [],
            confirmedConcepts: [strategy.conceptTag, GoConcept.varsUnused, GoConcept.shortDeclaration])
            .flatMap(\.pairs)
        XCTAssertTrue(pairs.contains { $0.requiredLessonID == strategy.id })
        XCTAssertFalse(pairs.contains { $0.requiredLessonID == visitor.id })
        let newReadings = ReadingLessonCatalog.all.filter { GoConcept.designLessonTags.contains($0.conceptTag) }
        XCTAssertEqual(newReadings.count, 53)
        XCTAssertEqual(Set(newReadings.map(\.conceptTag)).count, 53)
    }
}
