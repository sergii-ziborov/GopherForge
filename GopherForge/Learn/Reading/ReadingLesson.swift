import Foundation

/// Reading material is bundled, so it never needs a compiler or a network request.
struct ReadingLesson: Codable, Sendable, Identifiable {
    struct Section: Codable, Sendable {
        let title: String
        let body: String
        let code: String?
        let language: String?
        let walkthrough: String?
    }
    let id: String
    let unitID: String
    let afterLessonID: String?
    let beforeLessonID: String?
    let title: String
    let objective: String
    let introduction: String
    let conceptTag: String
    let sections: [Section]
    let takeaway: String
    let references: [URL]
    let reviewPrompt: String
    let reviewAnswer: String
    let question: String
    let wrongAnswers: [String]
    let hint: String
    let nuance: String

    var lesson: Lesson {
        Lesson(id: id, title: title, objective: objective, explanation: introduction,
               conceptTags: [conceptTag], task: .reading, idiomaticSolution: nil)
    }
}

enum ReadingLessonCatalog {
    static let all: [ReadingLesson] = {
        #if LESSON_CATALOG_EXPORT
        // Command-line export uses the same source without needing an app bundle.
        let exportURL = ProcessInfo.processInfo.arguments.dropFirst().first.flatMap { argument -> URL? in
            guard argument.hasSuffix("/ReadingLessons.json") else { return nil }
            return URL(fileURLWithPath: argument)
        }
        let sourceURL = exportURL
        #else
        let sourceURL = Bundle.main.url(forResource: "ReadingLessons", withExtension: "json")
        #endif
        guard let url = sourceURL,
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([ReadingLesson].self, from: data) else { return [] }
        return lessons
    }()

    static func reading(for id: String) -> ReadingLesson? { all.first { $0.id == id } }

    static func expanding(_ unit: CourseUnit) -> CourseUnit {
        var lessons: [Lesson] = []
        for lesson in unit.lessons {
            lessons += all.filter { $0.unitID == unit.id && $0.beforeLessonID == lesson.id }.map(\.lesson)
            lessons.append(lesson)
            lessons += all.filter { $0.unitID == unit.id && $0.afterLessonID == lesson.id }.map(\.lesson)
        }
        return CourseUnit(id: unit.id, title: unit.title, summary: unit.summary,
                          translationNote: unit.translationNote, lessons: lessons)
    }

    static func unit(_ id: String, title: String, summary: String, note: String) -> CourseUnit {
        CourseUnit(id: id, title: title, summary: summary, translationNote: note,
                   lessons: all.filter { $0.unitID == id }.map(\.lesson))
    }
}
