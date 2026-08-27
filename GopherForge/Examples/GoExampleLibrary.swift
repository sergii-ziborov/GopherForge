import Foundation

/// Every example, in one place.
///
/// Split across three files by subject rather than kept in one, because the
/// catalog is content and content grows: a single file would be past this
/// project's size limit before it was interesting.
enum GoExampleLibrary {
    static let all: [GoExample] =
        GoExampleLibraryCore.all + GoExampleLibraryConcurrency.all + GoExampleLibraryStdlib.all

    static func example(id: String) -> GoExample? {
        all.first { $0.id == id }
    }

    /// Examples that exercise a concept, so one can be offered for something a
    /// learner keeps getting wrong rather than only browsed alphabetically.
    static func examples(forConcept tag: String) -> [GoExample] {
        all.filter { $0.conceptTags.contains(tag) }
    }

    /// Grouped for display. The order is the order of the catalogs, which runs
    /// language first and library last, the way the course does.
    static var sections: [(title: String, examples: [GoExample])] {
        [
            ("The language", GoExampleLibraryCore.all),
            ("Concurrency", GoExampleLibraryConcurrency.all),
            ("Standard library", GoExampleLibraryStdlib.all),
        ]
    }
}
