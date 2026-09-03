import Foundation

/// The quizzes closing the two units added last.
///
/// Options are kept short on purpose — the limit is checked by a test, because
/// a multiple choice is meant to be answered at a glance and a paragraph in an
/// option is a reading exercise wearing a quiz's clothes.
enum QuizCatalogTypes {
    static let structs = Quiz(
        unitID: "structs",
        title: "Types you define",
        questions: [
            QuizQuestion(
                id: "structs.q.literal",
                prompt: "Why is the named form preferred for a struct literal?",
                code: "p := Point{X: 1, Y: 2}\nq := Point{1, 2}",
                options: [
                    "It is faster to compile",
                    "It is the only form vet accepts",
                    "It survives a field being added",
                    "It allows fields to be omitted",
                ],
                correctIndex: 2,
                explanation: "The positional form depends on declaration order, so inserting "
                    + "a field silently reassigns every value after it. Both forms let you "
                    + "omit fields; the omitted ones take their zero value.",
                conceptTag: GoConcept.structLiteral
            ),
            QuizQuestion(
                id: "structs.q.receiver",
                prompt: "Grow has a value receiver and increments a field. What does the caller see?",
                code: "func (r Rect) Grow() { r.Width++ }",
                options: [
                    "Nothing; it changed a copy",
                    "The increment, as normal",
                    "A compile error",
                    "A panic at run time",
                ],
                correctIndex: 0,
                explanation: "A value receiver is a copy. The method compiles, runs and mutates "
                    + "the copy, and nothing warns you that the change went nowhere.",
                conceptTag: GoConcept.pointerReceiver
            ),
            QuizQuestion(
                id: "structs.q.zero",
                prompt: "What is `var p Point` before anything is assigned to it?",
                code: "type Point struct{ X, Y int }",
                options: [
                    "nil, until it is made",
                    "Undefined memory",
                    "A compile error until initialised",
                    "A struct with X and Y at 0",
                ],
                correctIndex: 3,
                explanation: "A struct is never nil. Its zero value has every field at that "
                    + "field's own zero, and the variable is usable straight away.",
                conceptTag: GoConcept.structLiteral
            ),
            QuizQuestion(
                id: "structs.q.escape",
                prompt: "A function returns the address of a local variable. What happens?",
                code: "func New() *Config {\n\tc := Config{}\n\treturn &c\n}",
                options: [
                    "It compiles; the value escapes",
                    "A dangling pointer at run time",
                    "A compile error",
                    "It works only for small types",
                ],
                correctIndex: 0,
                explanation: "Escape analysis notices the value outlives the call and allocates "
                    + "it where it survives. This is ordinary Go — every New... does it.",
                conceptTag: GoConcept.pointerReceiver
            ),
            QuizQuestion(
                id: "structs.q.closure",
                prompt: "What do two closures over the same variable share?",
                code: "count := 0\nup := func() { count++ }\nread := func() int { return count }",
                options: [
                    "Nothing; each copies it",
                    "The variable itself",
                    "Only its value at capture",
                    "Nothing until they are called",
                ],
                correctIndex: 1,
                explanation: "A closure captures the variable, not its value, so writes made "
                    + "through one are visible through the other.",
                conceptTag: GoConcept.closure
            ),
        ]
    )

    static let generics = Quiz(
        unitID: "generics",
        title: "Generics",
        questions: [
            QuizQuestion(
                id: "generics.q.tilde",
                prompt: "What does the ~ add to a constraint?",
                code: "type Number interface{ ~int | ~float64 }",
                options: [
                    "It makes the type optional",
                    "It allows pointers to them",
                    "It marks the default type",
                    "It admits named types too",
                ],
                correctIndex: 3,
                explanation: "~float64 means any type whose underlying type is float64, so "
                    + "`type Celsius float64` is admitted. Without it, only float64 itself is.",
                conceptTag: GoConcept.constraint
            ),
            QuizQuestion(
                id: "generics.q.any",
                prompt: "How does `any` as a constraint differ from interface{} as a parameter?",
                code: "func A[T any](v T)\nfunc B(v interface{})",
                options: [
                    "A keeps the caller's type",
                    "They are identical",
                    "B is checked at compile time",
                    "A is slower to call",
                ],
                correctIndex: 0,
                explanation: "A gets the caller's actual type, so its result stays typed and "
                    + "mistakes are compile errors. B gets a value the caller must assert out of.",
                conceptTag: GoConcept.typeParameter
            ),
            QuizQuestion(
                id: "generics.q.method",
                prompt: "Can a method introduce a type parameter of its own?",
                code: "func (s *Stack[T]) Map[U any](f func(T) U) []U",
                options: [
                    "Yes, like a function",
                    "Only if the receiver is a value",
                    "No; it must be a function",
                    "Only with a constraint",
                ],
                correctIndex: 2,
                explanation: "Methods repeat the type's parameters but cannot add new ones, "
                    + "which is why Map is a function in every Go library and a method in none.",
                conceptTag: GoConcept.typeParameter
            ),
            QuizQuestion(
                id: "generics.q.zero",
                prompt: "How do you return the zero value of a type parameter T?",
                code: "func Pop[T any]() (T, bool)",
                options: [
                    "return nil, false",
                    "var zero T; return zero, false",
                    "return T{}, false",
                    "return *new(T), false only",
                ],
                correctIndex: 1,
                explanation: "T might be a string or an int, for which nil is not a value, and "
                    + "T{} is not valid for every type. A declared variable is the zero of "
                    + "whatever T turned out to be.",
                conceptTag: GoConcept.typeParameter
            ),
            QuizQuestion(
                id: "generics.q.overuse",
                prompt: "The constraint is an interface with one method and nothing else. Now what?",
                code: "func Print[T Stringer](v T) { fmt.Println(v.String()) }",
                options: [
                    "Keep it; it avoids dispatch",
                    "Add a second type parameter",
                    "Drop the constraint for any",
                    "Take the interface as a parameter",
                ],
                correctIndex: 3,
                explanation: "Nothing here needs the concrete type: no container to keep typed, "
                    + "no operator, no second type. The plain interface parameter says the same "
                    + "thing and reads once instead of twice.",
                conceptTag: GoConcept.genericsOveruse
            ),
        ]
    )
}
