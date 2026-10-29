import CryptoKit
import Foundation

/// Assistance observed inside this app. It does not infer who authored pasted code.
enum LessonAssistance: String, Codable, Sendable {
    case none, hint, solutionRevealed, solutionInserted
}

struct LessonDraft: Codable, Equatable, Sendable {
    var schemaVersion = 1
    let lessonID: String
    let contentRevision: String
    let text: String
    let ownTextBeforeSolution: String?
    let assistance: LessonAssistance
    let updatedAt: Date
}

/// One local document per lesson. An older screen cannot overwrite a newer
/// screen's work; its last draft is preserved as a separately named recovery.
actor LessonDraftStore {
    static let shared = LessonDraftStore()
    struct Session: Sendable { let token: UUID; let draft: LessonDraft? }
    enum DraftError: LocalizedError {
        case unsupported, tooLarge, superseded
        var errorDescription: String? {
            switch self {
            case .unsupported: "This lesson draft uses an unsupported or damaged format. It has not been replaced."
            case .tooLarge: "This draft exceeds the 1 MiB source limit. Copy your code before leaving."
            case .superseded: "Another screen opened this lesson. This screen’s code was kept as a separate recovery draft; the newer screen was not overwritten."
            }
        }
    }
    private let folder: URL
    private var sessions: [String: UUID] = [:]
    private var revisions: [UUID: UInt64] = [:]

    init(folder: URL? = nil) {
        self.folder = folder ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appending(path: "GopherForge/LessonDrafts", directoryHint: .isDirectory)
    }
    func open(lessonID: String) throws -> Session {
        let url = path(lessonID)
        let draft = FileManager.default.fileExists(atPath: url.path) ? try decode(url, lessonID: lessonID) : nil
        let token = UUID()
        sessions[lessonID] = token
        return Session(token: token, draft: draft)
    }
    func save(_ draft: LessonDraft, token: UUID, revision: UInt64) throws {
        guard draft.text.utf8.count <= 1_048_576,
              (draft.ownTextBeforeSolution?.utf8.count ?? 0) <= 1_048_576 else { throw DraftError.tooLarge }
        if let accepted = revisions[token], revision < accepted { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = path(draft.lessonID)
        let data = try JSONEncoder.gopherForge.encode(draft)
        guard sessions[draft.lessonID] == token else {
            let recovery = url.deletingPathExtension().appendingPathExtension("recovery-\(token.uuidString).json")
            try data.write(to: recovery, options: .atomic)
            revisions[token] = revision
            throw DraftError.superseded
        }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try decode(url, lessonID: draft.lessonID) // Refuse unknown schemas before writing.
            try Data(contentsOf: url).write(to: url.deletingPathExtension().appendingPathExtension("previous.json"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else { throw DraftError.unsupported }
        revisions[token] = revision
    }
    private func decode(_ url: URL, lessonID: String) throws -> LessonDraft {
        let data = try Data(contentsOf: url)
        guard data.count <= 4 * 1_048_576 else { throw DraftError.tooLarge }
        let draft = try JSONDecoder.gopherForge.decode(LessonDraft.self, from: data)
        guard draft.schemaVersion == 1, draft.lessonID == lessonID else { throw DraftError.unsupported }
        return draft
    }
    private func path(_ id: String) -> URL {
        folder.appending(path: Self.digest([id]) + ".json")
    }
    static func contentRevision(for lesson: Lesson) -> String {
        let task: [String]
        switch lesson.task {
        case .reading: task = ["reading"]
        case let .compile(starter, test): task = ["compile", starter, test]
        case let .guidedTyping(target): task = ["guidedTyping", target]
        case let .fillGaps(template, blanks): task = ["fillGaps", template] + blanks
        case let .predict(source, question, answer): task = ["predict", source, question, answer]
        }
        return digest([lesson.id] + task)
    }
    private static func digest(_ values: [String]) -> String {
        SHA256.hash(data: (try? JSONEncoder().encode(values)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
}
