import Foundation

/// Authored explanations and vector diagrams shared with the product website.
struct LessonGuide: Codable, Equatable, Sendable, Identifiable {
    enum Mode: String, Codable, Sendable {
        case flow, sequence, comparison, stack, shared, fanout
    }
    struct Node: Codable, Equatable, Sendable {
        let label: String
        let code: String
        let detail: String
    }
    let id: String
    let title: String
    let mode: Mode
    let nodes: [Node]
    let caption: String
    let practical: String
    let watchOut: String
    let reference: URL
}

#if !LESSON_CATALOG_EXPORT
enum LessonGuideCatalog {
    static var all: [LessonGuide] { CourseLibrary.shared.packages.flatMap(\.guides) }
    static func guide(for id: String) -> LessonGuide? { all.first { $0.id == id } }
}

#endif
