import Foundation

/// Shared, authored interview preparation. This resource is copied byte-for-byte
/// into the web build; progress stays separate from compiler-verified lessons.
struct InterviewPrepBank: Decodable, Sendable {
    let schemaVersion: Int
    let reviewedOn: String
    let levels: [String]
    let topics: [InterviewPrepTopic]
    let questions: [InterviewPrepQuestion]
    let demonstrations: [AlgorithmDemonstration]

    static let shared: InterviewPrepBank = {
        do {
            guard let url = Bundle.main.url(forResource: "InterviewPrep", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("Interview preparation could not be loaded: \(error)")
            return Self(schemaVersion: 1, reviewedOn: "", levels: [], topics: [], questions: [], demonstrations: [])
        }
    }()

    func filtered(topic: String, level: Int, search: String) -> [InterviewPrepQuestion] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return questions.filter {
            (topic.isEmpty || $0.topic == topic) && (level == 0 || $0.level == level)
                && (query.isEmpty || [$0.title, $0.prompt, $0.topic, $0.answerPoints.joined(separator: " ")]
                    .joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
    }
}
struct InterviewPrepTopic: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let route: String
}
struct InterviewPrepQuestion: Decodable, Identifiable, Sendable {
    let id: String
    let topic: String
    let level: Int
    let title: String
    let prompt: String
    let answerPoints: [String]
    let trap: String
    let exercise: String
    let solution: String
    let followUp: String
    let references: [String]
    let code: String
    let complexity: String
}
struct AlgorithmDemonstration: Decodable, Identifiable, Sendable {
    let id: String
    let cases: [AlgorithmCase]
}
struct AlgorithmCase: Decodable, Sendable {
    let name: String
    let input: String
    let result: String
    let steps: [AlgorithmStep]
}
struct AlgorithmStep: Decodable, Sendable {
    let title: String
    let note: String
    let rows: [AlgorithmRow]
}
struct AlgorithmRow: Decodable, Sendable {
    let label: String
    let values: [String]
    let active: [Int]
}
