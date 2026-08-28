import Foundation

/// What happened when a learner attempted a lesson.
///
/// The mistake tags are the product's memory. They come from the compiler, the
/// hidden test and the idiom coach rather than from a quiz score, which is why
/// review can target what someone actually gets wrong in code.
struct LessonAttempt: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let lessonID: String
    let succeeded: Bool
    let attemptedAt: Date
    /// Concept tags observed as mistakes during this attempt.
    let mistakeTags: [String]
    /// How many times the learner ran the compiler before succeeding. A high
    /// count with an eventual pass is a different signal from a first-try pass.
    let compileAttempts: Int
    /// Whether the compiler judged this, or the learner said so.
    ///
    /// Optional because attempts written before self-marking existed do not
    /// carry it, and a new non-optional field would turn every old install's
    /// history into a decode failure. Read it through `isCompilerVerified`.
    let compilerVerified: Bool?

    /// A pass the toolchain actually witnessed.
    ///
    /// Older records fall back to the count: nothing could be marked by hand
    /// then except a guided-typing lesson, which ran no compiler either.
    var isCompilerVerified: Bool { compilerVerified ?? (compileAttempts > 0) }

    /// The learner said they had done it. The app believes them and says so —
    /// it does not claim the compiler agreed.
    var isSelfReported: Bool { succeeded && !isCompilerVerified }

    init(
        id: UUID = UUID(),
        lessonID: String,
        succeeded: Bool,
        attemptedAt: Date = Date(),
        mistakeTags: [String] = [],
        compileAttempts: Int = 0,
        compilerVerified: Bool? = nil
    ) {
        self.id = id
        self.lessonID = lessonID
        self.succeeded = succeeded
        self.attemptedAt = attemptedAt
        self.mistakeTags = mistakeTags
        self.compileAttempts = compileAttempts
        self.compilerVerified = compilerVerified
    }
}

extension LessonAttempt {
    /// Builds an attempt from what the toolchain and the coach reported, so
    /// nothing has to guess at the tags.
    static func from(
        lessonID: String,
        result: CompilationResult,
        findings: [IdiomFinding],
        compileAttempts: Int
    ) -> LessonAttempt {
        let compilerTags = result.diagnostics.compactMap(\.conceptTag)
        let idiomTags = findings.map(\.conceptTag)
        let passed = result.succeeded && (result.tests.isEmpty || result.tests.allPassed)
        return LessonAttempt(
            lessonID: lessonID,
            succeeded: passed,
            mistakeTags: Array(Set(compilerTags + idiomTags)).sorted(),
            compileAttempts: compileAttempts,
            compilerVerified: true
        )
    }
}
