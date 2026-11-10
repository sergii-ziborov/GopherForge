import Foundation

/// Every quiz, keyed by the unit it closes.
enum QuizCatalog {
    #if LESSON_CATALOG_EXPORT
    static let all: [Quiz] = [
        QuizCatalogCore.core,
        QuizCatalogTypes.structs,
        QuizCatalogCore.collections,
        QuizCatalogAdvanced.interfaces,
        QuizCatalogTypes.generics,
        QuizCatalogAdvanced.errors,
        QuizCatalogConcurrency.concurrency,
        QuizCatalogConcurrency.modules,
        QuizCatalogConcurrency.standardLibrary,
    ]

    #else
    static var all: [Quiz] { CourseLibrary.shared.packages.flatMap { $0.practice.quizzes } }
    #endif

    static func quiz(forUnit unitID: String) -> Quiz? {
        all.first { $0.unitID == unitID }
    }

    static var questionCount: Int {
        all.reduce(0) { $0 + $1.questions.count }
    }
}
