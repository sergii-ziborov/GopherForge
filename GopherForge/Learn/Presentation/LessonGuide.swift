import Foundation

/// Authored explanations and vector diagrams shared with the product website.
struct LessonGuide: Decodable, Equatable, Sendable, Identifiable {
    enum Mode: String, Decodable, Sendable {
        case flow, sequence, comparison, stack, shared, fanout
    }
    struct Node: Decodable, Equatable, Sendable {
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

enum LessonGuideCatalog {
    static let all: [LessonGuide] = {
        guard let url = Bundle.main.url(forResource: "LessonGuides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let guides = try? JSONDecoder().decode([LessonGuide].self, from: data) else { return [] }
        return guides
    }()
    static func guide(for id: String) -> LessonGuide? { all.first { $0.id == id } }
}
