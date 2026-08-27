import XCTest
@testable import GopherForge

/// The quiz's rules and the content they run on.
@MainActor
final class QuizSessionTests: XCTestCase {
    private let quiz = Quiz(
        unitID: "test",
        title: "Test",
        questions: (0..<5).map { index in
            QuizQuestion(
                id: "q\(index)",
                prompt: "Question \(index)",
                code: "",
                options: ["a", "b", "c", "d"],
                correctIndex: index % 4,
                explanation: "Because.",
                conceptTag: "concept.\(index)"
            )
        }
    )

    func testAnsweringAdvancesOnlyWhenAsked() {
        let session = QuizSession(quiz: quiz)

        session.choose(0)

        XCTAssertEqual(session.index, 0, "the explanation is shown before the next question")
        XCTAssertEqual(session.chosenIndex, 0)

        session.advance()
        XCTAssertEqual(session.index, 1)
        XCTAssertNil(session.chosenIndex)
    }

    /// The second tap is almost always a mis-tap on the explanation that just
    /// appeared, and it must not become an answer.
    func testAnsweringTwiceChangesNothing() {
        let session = QuizSession(quiz: quiz)

        session.choose(0)
        session.choose(3)

        XCTAssertEqual(session.chosenIndex, 0)
        XCTAssertEqual(session.answers.count, 1)
    }

    func testAdvancingWithoutAnsweringDoesNothing() {
        let session = QuizSession(quiz: quiz)

        session.advance()

        XCTAssertEqual(session.index, 0)
    }

    func testScoreAndConceptsFollowTheAnswers() {
        let session = QuizSession(quiz: quiz)

        for question in quiz.questions {
            // Right for even questions, wrong for odd ones.
            let index = Int(question.id.dropFirst()) ?? 0
            session.choose(index.isMultiple(of: 2) ? question.correctIndex : (question.correctIndex + 1) % 4)
            session.advance()
        }

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.correctCount, 3)
        XCTAssertEqual(session.mistakenConcepts, ["concept.1", "concept.3"])
        XCTAssertEqual(session.progress, 1)
    }

    /// Four in five passes: high enough to mean something, low enough that one
    /// slip is not a failure.
    func testPassingNeedsFourInFive() {
        XCTAssertTrue(quiz.passed(correct: 4))
        XCTAssertTrue(quiz.passed(correct: 5))
        XCTAssertFalse(quiz.passed(correct: 3))
    }

    func testRestartClearsEverything() {
        let session = QuizSession(quiz: quiz)
        session.choose(0)
        session.advance()

        session.restart()

        XCTAssertEqual(session.index, 0)
        XCTAssertTrue(session.answers.isEmpty)
        XCTAssertNil(session.chosenIndex)
    }
}

/// The authored questions.
final class QuizCatalogTests: XCTestCase {
    func testEveryUnitWithLessonsHasAQuiz() {
        for unit in GoCourseCatalog.units where !unit.lessons.isEmpty {
            XCTAssertNotNil(
                QuizCatalog.quiz(forUnit: unit.id),
                "unit \(unit.id) has lessons but no quiz to close it"
            )
        }
    }

    func testEveryQuestionIsWellFormed() {
        for quiz in QuizCatalog.all {
            XCTAssertFalse(quiz.questions.isEmpty, "\(quiz.unitID) has no questions")
            XCTAssertLessThanOrEqual(quiz.questions.count, Quiz.maximumQuestions)

            for question in quiz.questions {
                XCTAssertEqual(question.options.count, 4, "\(question.id) should offer four options")
                XCTAssertTrue(
                    question.options.indices.contains(question.correctIndex),
                    "\(question.id) points at an option that does not exist"
                )
                XCTAssertEqual(
                    Set(question.options).count, question.options.count,
                    "\(question.id) repeats an option"
                )
                XCTAssertFalse(question.explanation.isEmpty, "\(question.id) explains nothing")
                XCTAssertFalse(question.prompt.isEmpty)
            }
        }
    }

    /// A long option is unreadable at a glance, and a glance is what a multiple
    /// choice is for.
    func testOptionsFitOnAPhone() {
        for quiz in QuizCatalog.all {
            for question in quiz.questions {
                for option in question.options {
                    XCTAssertLessThanOrEqual(
                        option.count, Quiz.maximumOptionCharacters,
                        "\(question.id) has an option too long to read at a glance: \(option)"
                    )
                }
            }
        }
    }

    /// The right answer must not be in the same place every time, or the quiz
    /// tests pattern-spotting rather than knowledge.
    func testTheRightAnswerMovesAround() {
        for quiz in QuizCatalog.all {
            let positions = Set(quiz.questions.map(\.correctIndex))
            XCTAssertGreaterThanOrEqual(
                positions.count, 2,
                "\(quiz.unitID) puts the right answer in the same place every time"
            )
        }
    }

    /// A wrong answer goes into the review queue, which looks the concept up in
    /// the course. A tag no lesson teaches is a dead end.
    func testEveryQuestionTagsAConceptTheCourseTeaches() {
        let known = Set(GoCourseCatalog.lessons.flatMap(\.conceptTags))
        for quiz in QuizCatalog.all {
            for question in quiz.questions {
                XCTAssertTrue(
                    known.contains(question.conceptTag),
                    "\(question.id) tags \(question.conceptTag), which no lesson teaches"
                )
            }
        }
    }

    func testQuestionIdentifiersAreUnique() {
        let ids = QuizCatalog.all.flatMap { $0.questions.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
