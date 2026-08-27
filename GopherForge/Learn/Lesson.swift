import Foundation

/// One lesson: a thing to understand, a thing to do, and a way to know it worked.
///
/// The verification is a hidden test compiled and run by the same bundled
/// toolchain the Build side uses. A lesson never marks itself complete on a
/// text match; it passes when Go says it passes.
struct Lesson: Identifiable, Equatable, Sendable {
    /// What the learner is asked to do, and how the app decides they did it.
    enum Task: Equatable, Sendable {
        /// Type the shape until it is muscle memory. Wrong keys are recorded
        /// and never inserted.
        case guidedTyping(target: String)
        /// Fill the holes in an otherwise complete program.
        case fillGaps(template: String, blanks: [String])
        /// Write or repair code until a hidden test passes.
        case compile(starter: String, hiddenTest: String)
        /// Predict what a program does before running it.
        case predict(source: String, question: String, answer: String)
    }

    let id: String
    let title: String
    /// One sentence: what the learner will be able to do afterwards.
    let objective: String
    /// The explanation, written for someone who already programs and is
    /// carrying habits from another language.
    let explanation: String
    let conceptTags: [String]
    let task: Task
    /// The idiomatic answer, shown after the attempt rather than before it.
    let idiomaticSolution: String?

    /// A complete `main.go` that passes this lesson's hidden test.
    ///
    /// Held apart from `idiomaticSolution`, which is a fragment written to be
    /// read. This one is written to be compiled: `LessonSolutionGateTests`
    /// builds it against the hidden test and requires the test to pass, which
    /// is the only way to know a lesson is solvable at all.
    var verifiedSolution: String? { LessonSolutionCatalog.solution(for: id) }

    var requiresCompiler: Bool {
        if case .compile = task { return true }
        return false
    }
}

/// A group of lessons that belong together.
struct CourseUnit: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    /// Why this unit exists for someone who already knows another language.
    let translationNote: String
    let lessons: [Lesson]

    var conceptTags: Set<String> {
        Set(lessons.flatMap(\.conceptTags))
    }
}
