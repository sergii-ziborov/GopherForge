import Foundation

/// Quizzes for interfaces, errors, concurrency and the standard library.
enum QuizCatalogAdvanced {
    static let interfaces = Quiz(
        unitID: "interfaces",
        title: "Interfaces",
        questions: [
            QuizQuestion(
                id: "iface.q.methodset",
                prompt: "Add is declared on *Counter. Which type satisfies Adder?",
                code: "type Adder interface{ Add() }\nfunc (c *Counter) Add() { c.n++ }",
                options: ["Both", "*Counter", "Counter", "Neither"],
                correctIndex: 1,
                explanation: "A pointer receiver puts the method in *Counter's method set only. "
                    + "A value receiver would put it in both.",
                conceptTag: GoConcept.methodSet
            ),
            QuizQuestion(
                id: "iface.q.nil",
                prompt: "Why does this print \"not nil\"?",
                code: "var p *MyError = nil\nvar err error = p\nif err != nil { fmt.Println(\"not nil\") }",
                options: [
                    "Because p was never assigned",
                    "The interface holds a type and a value; only the value is nil",
                    "Because MyError does not implement error",
                    "It does not — this prints nothing",
                ],
                correctIndex: 1,
                explanation: "An interface is nil only when both its type and its value are. "
                    + "Return a bare nil rather than a typed nil pointer.",
                conceptTag: GoConcept.nilInterface
            ),
            QuizQuestion(
                id: "iface.q.small",
                prompt: "Which interface is easier for callers to satisfy?",
                code: "",
                options: [
                    "One with five methods, so it is complete",
                    "One that embeds three others",
                    "One with a single method",
                    "It makes no difference",
                ],
                correctIndex: 2,
                explanation: "io.Reader is one method, and half the standard library accepts it. "
                    + "The larger the interface, the fewer things can be passed to you.",
                conceptTag: GoConcept.smallInterface
            ),
            QuizQuestion(
                id: "iface.q.accept",
                prompt: "Where should an interface usually be declared?",
                code: "",
                options: [
                    "In the package that consumes it",
                    "In the package that implements it",
                    "In a shared interfaces package",
                    "Anywhere — it makes no difference",
                ],
                correctIndex: 0,
                explanation: "The consumer knows what it needs. Declaring it there keeps the "
                    + "interface as small as the use, and implementers need not import anything.",
                conceptTag: GoConcept.smallInterface
            ),
        ]
    )

    static let errors = Quiz(
        unitID: "errors",
        title: "Errors",
        questions: [
            QuizQuestion(
                id: "err.q.wrap",
                prompt: "Which keeps the original error reachable?",
                code: "",
                options: [
                    "fmt.Errorf(\"load: %v\", err)",
                    "fmt.Errorf(\"load: %w\", err)",
                    "errors.New(\"load: \" + err.Error())",
                    "Both %v and %w",
                ],
                correctIndex: 1,
                explanation: "%w wraps: errors.Is and errors.As can still see through it. "
                    + "%v formats it into a string and the original is gone.",
                conceptTag: GoConcept.errorWrapping
            ),
            QuizQuestion(
                id: "err.q.is",
                prompt: "How should a caller test for a known error?",
                code: "",
                options: [
                    "err == io.EOF",
                    "errors.Is(err, io.EOF)",
                    "err.Error() == \"EOF\"",
                    "reflect.TypeOf(err) == reflect.TypeOf(io.EOF)",
                ],
                correctIndex: 1,
                explanation: "errors.Is unwraps. A direct == fails the moment anyone adds "
                    + "context with %w, and comparing strings breaks on a reworded message.",
                conceptTag: GoConcept.errorSentinel
            ),
            QuizQuestion(
                id: "err.q.defer",
                prompt: "When does the deferred call run?",
                code: "f, err := os.Open(name)\nif err != nil { return err }\ndefer f.Close()",
                options: [
                    "At the end of the enclosing block",
                    "When the function returns, however it returns",
                    "Only on a normal return, not on a panic",
                    "Immediately, on the next line",
                ],
                correctIndex: 1,
                explanation: "Function scope, not block scope, and it runs on a panic too. That "
                    + "is what makes it the right place for cleanup.",
                conceptTag: GoConcept.deferCleanup
            ),
            QuizQuestion(
                id: "err.q.ignore",
                prompt: "What is wrong with this?",
                code: "value, _ := strconv.Atoi(input)",
                options: [
                    "Nothing, if you are sure input is a number",
                    "It will not compile",
                    "A failure silently becomes 0",
                    "Atoi never returns an error",
                ],
                correctIndex: 2,
                explanation: "On failure Atoi returns 0 and an error. Discarding the error turns "
                    + "bad input into a plausible-looking zero, which is the hardest bug to find.",
                conceptTag: GoConcept.explicitErrorCheck
            ),
        ]
    )
}
