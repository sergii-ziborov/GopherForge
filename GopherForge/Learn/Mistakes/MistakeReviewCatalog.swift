import Foundation

struct MistakeReviewQuestion: Identifiable, Equatable, Sendable {
    let question: QuizQuestion
    let unitID: String
    var id: String { question.id }
}

/// Reuse authored explanations and distractors, with exactly three answers.
/// Matching remains on Review; this catalog asks one question at a time.
enum MistakeReviewCatalog {
    static let all: [MistakeReviewQuestion] = {
        var questions = QuizCatalog.all.flatMap { quiz in
            quiz.questions.map { MistakeReviewQuestion(question: $0, unitID: quiz.unitID) }
        } + diagnosticQuestions
        var covered = Set(questions.map { $0.question.conceptTag })
        for pair in ReviewMatchCatalog.allPairs where !covered.contains(pair.conceptTag) {
            guard let lessonID = pair.requiredLessonID,
                  let lesson = GoCourseCatalog.lesson(id: lessonID),
                  let unit = GoCourseCatalog.unit(containing: lessonID) else { continue }
            let otherAnswers = ReviewMatchCatalog.allPairs.filter {
                $0.id != pair.id && $0.answer != pair.answer
            }.prefix(2).map(\.answer)
            questions.append(MistakeReviewQuestion(
                question: QuizQuestion(
                    id: "mistake.\(pair.id)", prompt: "Which statement describes \(pair.prompt)?",
                    code: pair.promptIsCode ? pair.prompt : "",
                    options: [pair.answer] + otherAnswers, correctIndex: 0,
                    explanation: pair.answer + ".\n\n" + (lesson.explanation.components(separatedBy: "\n\n").first ?? lesson.objective),
                    conceptTag: pair.conceptTag
                ), unitID: unit.id
            ))
            covered.insert(pair.conceptTag)
        }
        return questions.enumerated().map { ordinal, item in
            let source = item.question
            let wrong = source.options.enumerated().filter { $0.offset != source.correctIndex }.prefix(2).map(\.element)
            var options = wrong
            let correctIndex = ordinal % 3
            options.insert(source.correctAnswer, at: correctIndex)
            return MistakeReviewQuestion(question: QuizQuestion(
                id: source.id, prompt: source.prompt, code: source.code,
                options: options, correctIndex: correctIndex,
                explanation: source.explanation, conceptTag: source.conceptTag
            ), unitID: item.unitID)
        }
    }()

    static func pendingQuestions(
        concepts: [String], history: [MistakeReviewAttempt]
    ) -> [MistakeReviewQuestion] {
        concepts.compactMap { tag in
            // Return to the exact unanswered mistake after leaving a session.
            // Choosing the least-seen question first would replace it with a
            // different question about the same concept on the next launch.
            if let latest = history.enumerated().filter({ $0.element.conceptTag == tag }).max(by: {
                $0.element.attemptedAt == $1.element.attemptedAt
                    ? $0.offset < $1.offset : $0.element.attemptedAt < $1.element.attemptedAt
            })?.element,
               !latest.succeeded, let id = latest.questionID,
               let question = all.first(where: { $0.id == id }) {
                return question
            }
            return ordered(all.filter { $0.question.conceptTag == tag }, history: history).first
        }
    }

    static func practiceQuestions(
        completed: Set<String>, history: [MistakeReviewAttempt]
    ) -> [MistakeReviewQuestion] {
        let knownTags = Set(GoCourseCatalog.lessons.filter { completed.contains($0.id) }.flatMap(\.conceptTags))
        let candidates = knownTags.isEmpty
            ? all.filter { $0.unitID == "core" }
            : all.filter { knownTags.contains($0.question.conceptTag) }
        return Array(ordered(candidates, history: history).prefix(10))
    }

    private static func ordered(
        _ questions: [MistakeReviewQuestion], history: [MistakeReviewAttempt]
    ) -> [MistakeReviewQuestion] {
        var lastSeen: [String: Date] = [:]
        for attempt in history {
            if let id = attempt.questionID {
                lastSeen[id] = max(lastSeen[id] ?? .distantPast, attempt.attemptedAt)
            }
        }
        return questions.enumerated().sorted { lhs, rhs in
            let left = lastSeen[lhs.element.id] ?? .distantPast
            let right = lastSeen[rhs.element.id] ?? .distantPast
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }

    private static let diagnosticQuestions: [MistakeReviewQuestion] = [
        MistakeReviewQuestion(question: QuizQuestion(
            id: "mistake.return", prompt: "Why does this function report missing return?",
            code: "func answer(ok bool) int {\n    if ok { return 42 }\n}",
            options: ["The false branch can exit without returning an int", "Its return value must be named", "The parameter must be a pointer"],
            correctIndex: 0, explanation: "A function returning a value needs a terminating statement on every path. Add a return after the conditional, or make both branches return a value.",
            conceptTag: GoConcept.missingReturn
        ), unitID: "core"),
        MistakeReviewQuestion(question: QuizQuestion(
            id: "mistake.undefined", prompt: "The compiler reports undefined: parse. What should you check?",
            code: "value := parse(input)",
            options: ["The name is declared or imported in this scope", "The garbage collector has run", "The function has a pointer receiver"],
            correctIndex: 0, explanation: "A name must resolve in the current scope. Check its spelling, declaration, and package qualifier. Importing a package does not put its exported names directly into this scope.",
            conceptTag: GoConcept.undefinedSymbol
        ), unitID: "modules"),
        MistakeReviewQuestion(question: QuizQuestion(
            id: "mistake.assignment", prompt: "Why does this assignment fail?",
            code: "var n int\nvar s string = n",
            options: ["int is not assignable to string", "n was declared inside a function", "A zero int cannot be assigned"],
            correctIndex: 0, explanation: "The declared types do not match. To format an integer as decimal text, use strconv.Itoa(n). A string(n) conversion has different semantics: it produces the string representation of a Unicode code point.",
            conceptTag: GoConcept.typeAssignment
        ), unitID: "core"),
    ]
}
