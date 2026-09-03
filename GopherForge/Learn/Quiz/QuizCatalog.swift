import Foundation

/// Every quiz, keyed by the unit it closes.
enum QuizCatalog {
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

    static func quiz(forUnit unitID: String) -> Quiz? {
        all.first { $0.unitID == unitID }
    }

    static var questionCount: Int {
        all.reduce(0) { $0 + $1.questions.count }
    }
}
