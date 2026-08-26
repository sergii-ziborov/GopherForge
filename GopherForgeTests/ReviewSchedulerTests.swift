import XCTest
@testable import GopherForge

final class ReviewSchedulerTests: XCTestCase {
    private let scheduler = ReviewScheduler()

    func testWeakestConceptComesFirst() {
        let strong = mastery(GoConcept.channelClose, successes: 5, mistakes: 0)
        let weak = mastery(GoConcept.explicitErrorCheck, successes: 0, mistakes: 3)

        let items = scheduler.nextItems(mastery: [strong, weak])
        XCTAssertEqual(items.first?.conceptTag, GoConcept.explicitErrorCheck)
    }

    func testUntouchedConceptsAreNotScheduled() {
        let items = scheduler.nextItems(mastery: [mastery(GoConcept.mapZeroValue, successes: 0, mistakes: 0)])
        XCTAssertTrue(items.isEmpty)
    }

    func testALessonIsNotRepeatedWithinASession() {
        let items = scheduler.nextItems(
            mastery: [mastery(GoConcept.explicitErrorCheck, successes: 0, mistakes: 2)],
            excluding: Set(GoCourseCatalog.lessons(taggedWith: GoConcept.explicitErrorCheck).map(\.id))
        )
        XCTAssertTrue(items.isEmpty)
    }

    func testEveryItemExplainsWhyItAppeared() {
        let items = scheduler.nextItems(mastery: [mastery(GoConcept.deadlock, successes: 1, mistakes: 2)])
        XCTAssertFalse(items.first?.reason.isEmpty ?? true)
    }

    func testRecentMistakeWeakensStrength() {
        var recent = mastery(GoConcept.selectBranch, successes: 4, mistakes: 1)
        recent.lastMistakeAt = Date()
        var old = mastery(GoConcept.selectBranch, successes: 4, mistakes: 1)
        old.lastMistakeAt = Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)

        XCTAssertLessThan(recent.strength, old.strength)
    }

    private func mastery(_ tag: String, successes: Int, mistakes: Int) -> ConceptMastery {
        ConceptMastery(
            conceptTag: tag,
            successes: successes,
            mistakes: mistakes,
            lastSeenAt: Date(),
            lastMistakeAt: mistakes > 0 ? Date(timeIntervalSinceNow: -60 * 60 * 24 * 10) : nil
        )
    }
}
