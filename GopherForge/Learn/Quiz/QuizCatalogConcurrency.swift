import Foundation

/// Quizzes for concurrency, modules and the standard library.
enum QuizCatalogConcurrency {
    static let concurrency = Quiz(
        unitID: "concurrency",
        title: "Concurrency",
        questions: [
            QuizQuestion(
                id: "conc.q.deadlock",
                prompt: "What happens when this runs?",
                code: "func main() {\n\tch := make(chan int)\n\tch <- 1\n\tfmt.Println(<-ch)\n}",
                options: [
                    "It prints 1",
                    "fatal error: all goroutines are asleep - deadlock!",
                    "It prints 0",
                    "It blocks forever with no message",
                ],
                correctIndex: 1,
                explanation: "An unbuffered channel is a rendezvous: the send waits for a "
                    + "receiver, and the only goroutine that could receive is the one sending.",
                conceptTag: GoConcept.deadlock
            ),
            QuizQuestion(
                id: "conc.q.close",
                prompt: "Who should close a channel?",
                code: "",
                options: [
                    "The receiver, when it has had enough",
                    "The sender, and only once",
                    "Whichever finishes first",
                    "Nobody — the runtime does it",
                ],
                correctIndex: 1,
                explanation: "Closing tells receivers there is no more. A receiver cannot know "
                    + "that, and closing twice — or sending after a close — panics.",
                conceptTag: GoConcept.channelClose
            ),
            QuizQuestion(
                id: "conc.q.select",
                prompt: "What does a default case do in a select?",
                code: "",
                options: [
                    "Runs when every other case is ready",
                    "Runs last, always",
                    "Makes select return at once when nothing is ready",
                    "Repeats the select until a case fires",
                ],
                correctIndex: 2,
                explanation: "With a default, select never blocks. Without one, it waits for the "
                    + "first branch that becomes ready.",
                conceptTag: GoConcept.selectBranch
            ),
            QuizQuestion(
                id: "conc.q.wg",
                prompt: "Where does wg.Add(1) belong?",
                code: "for _, job := range jobs {\n\t???\n\tgo worker(job)\n}",
                options: [
                    "Inside the goroutine, first line",
                    "Before starting the goroutine",
                    "After the loop, once, with the total",
                    "It makes no difference",
                ],
                correctIndex: 1,
                explanation: "Add inside the goroutine races with Wait, which may see a counter "
                    + "of zero and return before anything started.",
                conceptTag: GoConcept.waitGroup
            ),
            QuizQuestion(
                id: "conc.q.leak",
                prompt: "The receiver returned early. What happens to this goroutine?",
                code: "go func() { results <- expensive() }()",
                options: [
                    "It is garbage collected",
                    "It blocks on the send forever and is never collected",
                    "The send fails with an error",
                    "It panics",
                ],
                correctIndex: 1,
                explanation: "A goroutine blocked on a channel nobody reads is a leak: it holds "
                    + "its stack and everything it references, for the life of the program.",
                conceptTag: GoConcept.goroutineLeak
            ),
            QuizQuestion(
                id: "conc.q.ctx",
                prompt: "Where does a context belong?",
                code: "",
                options: [
                    "Stored in the struct that needs it",
                    "As the first parameter, named ctx",
                    "In a package-level variable",
                    "Anywhere in the parameter list",
                ],
                correctIndex: 1,
                explanation: "First parameter, never stored. A stored context outlives the call "
                    + "it belonged to, and cancelling it then means nothing.",
                conceptTag: GoConcept.contextFirstParameter
            ),
        ]
    )

    static let modules = Quiz(
        unitID: "modules",
        title: "Modules and packages",
        questions: [
            QuizQuestion(
                id: "mod.q.dir",
                prompt: "What decides which package a file belongs to?",
                code: "",
                options: [
                    "Its directory",
                    "Its file name",
                    "The order of imports",
                    "The go.mod file",
                ],
                correctIndex: 0,
                explanation: "A directory is a package. Every file in it shares one package "
                    + "clause, and two different clauses in one directory is an error.",
                conceptTag: GoConcept.importPath
            ),
            QuizQuestion(
                id: "mod.q.internal",
                prompt: "Who can import example.com/app/internal/store?",
                code: "",
                options: [
                    "Anyone who knows the path",
                    "Only code inside example.com/app",
                    "Only the package that declares it",
                    "Nobody — internal is not importable",
                ],
                correctIndex: 1,
                explanation: "internal/ is enforced by the compiler: only code rooted at its "
                    + "parent may import it. It is how a module keeps an implementation private.",
                conceptTag: GoConcept.importPath
            ),
            QuizQuestion(
                id: "mod.q.export",
                prompt: "What makes an identifier visible outside its package?",
                code: "",
                options: [
                    "An export keyword",
                    "Declaring it at package level",
                    "A capital first letter",
                    "Listing it in go.mod",
                ],
                correctIndex: 2,
                explanation: "Case is the visibility rule. Message is exported, message is not, "
                    + "and there is no third level.",
                conceptTag: GoConcept.importPath
            ),
            QuizQuestion(
                id: "mod.q.path",
                prompt: "What is the module path in go.mod for?",
                code: "module example.com/app",
                options: [
                    "It must be a real URL that resolves",
                    "It is the prefix every package in the module is imported by",
                    "It only names the folder",
                    "It picks the Go version",
                ],
                correctIndex: 1,
                explanation: "The module path prefixes every import inside it: the directory "
                    + "greet becomes example.com/app/greet.",
                conceptTag: GoConcept.importPath
            ),
        ]
    )

    static let standardLibrary = Quiz(
        unitID: "stdlib",
        title: "Standard library",
        questions: [
            QuizQuestion(
                id: "std.q.reader",
                prompt: "How many methods does io.Reader have?",
                code: "",
                options: ["One", "Two", "Three", "It depends on the implementation"],
                correctIndex: 0,
                explanation: "Read, and nothing else. That is why a file, a network connection "
                    + "and a string can all be passed to the same function.",
                conceptTag: GoConcept.stdlibIO
            ),
            QuizQuestion(
                id: "std.q.json",
                prompt: "Why does Unmarshal take a pointer?",
                code: "json.Unmarshal(data, &value)",
                options: [
                    "For speed",
                    "So it can fill a value the caller owns",
                    "Because JSON is always an object",
                    "It does not — that & is optional",
                ],
                correctIndex: 1,
                explanation: "Go passes everything by value. Without the pointer, Unmarshal "
                    + "would fill a copy and the caller would see nothing change.",
                conceptTag: GoConcept.stdlibJSON
            ),
            QuizQuestion(
                id: "std.q.subtest",
                prompt: "What does t.Run give you?",
                code: "t.Run(name, func(t *testing.T) { ... })",
                options: [
                    "A faster test",
                    "A subtest that can fail on its own and be run by name",
                    "A parallel test, always",
                    "A benchmark",
                ],
                correctIndex: 1,
                explanation: "Each case reports separately, so one failure does not hide the "
                    + "rest, and -run can select a single case by name.",
                conceptTag: GoConcept.stdlibTesting
            ),
            QuizQuestion(
                id: "std.q.scanner",
                prompt: "The loop ended. How do you know it was not an error?",
                code: "for scanner.Scan() { ... }",
                options: [
                    "Scan returns false only at EOF",
                    "Check scanner.Err() afterwards",
                    "Scan panics on an error",
                    "Errors are printed automatically",
                ],
                correctIndex: 1,
                explanation: "Scan returns false for both EOF and failure. Err() afterwards is "
                    + "the only thing that tells them apart.",
                conceptTag: GoConcept.stdlibIO
            ),
        ]
    )
}
