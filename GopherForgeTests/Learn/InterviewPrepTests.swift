import XCTest
@testable import GopherForge

final class InterviewPrepTests: XCTestCase {
    func testBundledGuidesAreCompleteAndStable() throws {
        let bank = InterviewPrepBank.shared
        XCTAssertEqual(bank.schemaVersion, 1)
        XCTAssertEqual(bank.questions.count, 88)
        XCTAssertEqual(bank.topics.count, 12)
        XCTAssertEqual(Set(bank.questions.map(\.id)).count, bank.questions.count)
        XCTAssertEqual(Set(bank.questions.map(\.level)), Set(1...4))
        let topics = Set(bank.topics.map(\.id))
        for q in bank.questions {
            XCTAssertTrue(topics.contains(q.topic), q.id)
            XCTAssertTrue((1...4).contains(q.level), q.id)
            XCTAssertGreaterThanOrEqual(q.answerPoints.count, 3, q.id)
            XCTAssertGreaterThan(q.solution.count, 80, q.id)
            XCTAssertFalse(q.trap.isEmpty, q.id)
            XCTAssertFalse(q.followUp.isEmpty, q.id)
            XCTAssertTrue(q.references.allSatisfy { URL(string: $0)?.scheme == "https" }, q.id)
        }
    }
    func testFiltersCombineInsteadOfIgnoringTheSelectedLevel() {
        let bank = InterviewPrepBank.shared
        XCTAssertEqual(bank.filtered(topic: "algorithms", level: 1, search: "boundary").map(\.id), ["algorithms.binary-search"])
        XCTAssertTrue(bank.filtered(topic: "mongodb", level: 4, search: "pool").contains { $0.id == "mongodb.load" })
        XCTAssertTrue(bank.filtered(topic: "redis", level: 1, search: "impossible-keyword-123").isEmpty)
        XCTAssertEqual(bank.filtered(topic: "", level: 0, search: "   ").count, 88)
    }
    func testTracesHaveSafeIndexesAndMeaningfulBoundaryCases() {
        let bank = InterviewPrepBank.shared
        XCTAssertEqual(bank.demonstrations.count, 8)
        for demo in bank.demonstrations {
            XCTAssertTrue(bank.questions.contains { $0.id == demo.id })
            XCTAssertEqual(demo.cases.count, 3, demo.id)
            for scenario in demo.cases {
                XCTAssertFalse(scenario.steps.isEmpty)
                XCTAssertFalse(scenario.result.isEmpty)
                for step in scenario.steps {
                    XCTAssertFalse(step.note.isEmpty)
                    for row in step.rows {
                        XCTAssertTrue(row.active.allSatisfy { row.values.indices.contains($0) }, "\(demo.id): \(step.title)")
                    }
                }
            }
        }
        let binary = bank.demonstrations.first { $0.id == "algorithms.binary-search" }!
        XCTAssertEqual(binary.cases.map(\.result), ["index 1", "index 0", "index 3"])
        let dp = bank.demonstrations.first { $0.id == "algorithms.dynamic-programming" }!
        XCTAssertEqual(dp.cases.map(\.result), ["minimum 2", "minimum -1", "minimum 0"])
    }
}
