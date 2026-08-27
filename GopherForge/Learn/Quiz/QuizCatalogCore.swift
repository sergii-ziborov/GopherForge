import Foundation

/// Quizzes for the first half of the course.
///
/// Every wrong option is a mistake people actually make rather than a made-up
/// one: an option nobody would choose does not test anything, it only makes the
/// right answer easier to spot.
enum QuizCatalogCore {
    static let core = Quiz(
        unitID: "core",
        title: "Go core",
        questions: [
            QuizQuestion(
                id: "core.q.short",
                prompt: "Where can this line appear?",
                code: "count := 0",
                options: [
                    "Anywhere a var declaration can",
                    "Inside a function only",
                    "At package level only",
                    "Only inside a for or if statement",
                ],
                correctIndex: 1,
                explanation: "Short declaration is function-scoped. At package level you must "
                    + "write var count = 0.",
                conceptTag: GoConcept.shortDeclaration
            ),
            QuizQuestion(
                id: "core.q.unused",
                prompt: "What does the compiler say?",
                code: "func main() {\n\thost := \"localhost\"\n\tfmt.Println(\"started\")\n}",
                options: [
                    "Nothing — it compiles",
                    "A warning about an unused variable",
                    "declared and not used: host",
                    "cannot use host as type string",
                ],
                correctIndex: 2,
                explanation: "An unused local is an error in Go, not a warning. Unused imports "
                    + "are the same. There is no flag to soften it.",
                conceptTag: GoConcept.varsUnused
            ),
            QuizQuestion(
                id: "core.q.zero",
                prompt: "What is the value of s?",
                code: "var s string",
                options: [
                    "nil",
                    "An empty string",
                    "Undefined until assigned",
                    "A compile error — it needs a value",
                ],
                correctIndex: 1,
                explanation: "Every Go value starts at its zero value. For a string that is \"\", "
                    + "for a pointer nil, for an int 0. There is no uninitialised memory.",
                conceptTag: GoConcept.shortDeclaration
            ),
            QuizQuestion(
                id: "core.q.multiple",
                prompt: "Why does Go return two values here?",
                code: "value, err := strconv.Atoi(\"12x\")",
                options: [
                    "To avoid exceptions: failure is a value you must handle",
                    "Because Atoi is generic",
                    "The second value is always ignored",
                    "To make the function faster",
                ],
                correctIndex: 0,
                explanation: "Go has no exceptions. A function that can fail returns an error "
                    + "beside its result, and the caller decides what to do about it.",
                conceptTag: GoConcept.explicitErrorCheck
            ),
            QuizQuestion(
                id: "core.q.import",
                prompt: "The file imports \"os\" but never mentions os again. What happens?",
                code: "",
                options: [
                    "Nothing — unused imports are ignored",
                    "The linker drops it silently",
                    "imported and not used: \"os\"",
                    "A warning, but it still builds",
                ],
                correctIndex: 2,
                explanation: "Same rule as an unused variable: it is an error. If you need the "
                    + "import only for its side effects, write _ \"os\".",
                conceptTag: GoConcept.unusedImport
            ),
        ]
    )

    static let collections = Quiz(
        unitID: "collections",
        title: "Slices, maps and strings",
        questions: [
            QuizQuestion(
                id: "coll.q.alias",
                prompt: "What does this print?",
                code: "a := []int{1, 2, 3, 4}\nb := a[1:3]\nb[0] = 99\nfmt.Println(a)",
                options: ["[1 2 3 4]", "[1 99 3 4]", "[99 2 3 4]", "[1 99 3]"],
                correctIndex: 1,
                explanation: "Reslicing does not copy. b shares a's backing array, so writing "
                    + "through b writes through a — until an append outgrows cap.",
                conceptTag: GoConcept.sliceAliasing
            ),
            QuizQuestion(
                id: "coll.q.append",
                prompt: "When does append stop writing into the original array?",
                code: "b = append(b, 100)",
                options: [
                    "Always — append always copies",
                    "Never — append always writes in place",
                    "When the result would exceed cap(b)",
                    "When len(b) is odd",
                ],
                correctIndex: 2,
                explanation: "Inside cap it writes in place and the sharing stays. Past cap it "
                    + "allocates a new array, and the two slices quietly stop being connected.",
                conceptTag: GoConcept.sliceCapacity
            ),
            QuizQuestion(
                id: "coll.q.map",
                prompt: "The map has no key \"nope\". What does this give?",
                code: "n := scores[\"nope\"]",
                options: [
                    "A panic",
                    "An error value",
                    "The zero value for the map's type",
                    "nil, whatever the type",
                ],
                correctIndex: 2,
                explanation: "Reading a missing key gives the zero value. Use the two-value form, "
                    + "n, ok := scores[\"nope\"], when absent and zero mean different things.",
                conceptTag: GoConcept.mapZeroValue
            ),
            QuizQuestion(
                id: "coll.q.len",
                prompt: "What is len(\"héllo\")?",
                code: "",
                options: ["5", "6", "10", "It depends on the locale"],
                correctIndex: 1,
                explanation: "len counts bytes. é is two bytes in UTF-8. Range over the string, "
                    + "or convert to []rune, to count characters.",
                conceptTag: GoConcept.stringRunes
            ),
            QuizQuestion(
                id: "coll.q.range",
                prompt: "In for i, r := range s, what is i?",
                code: "",
                options: [
                    "The character's position",
                    "The byte offset of the character",
                    "Always the same as the loop count",
                    "The rune's Unicode code point",
                ],
                correctIndex: 1,
                explanation: "i is a byte offset, so it jumps by more than one for multi-byte "
                    + "characters. r is the rune itself.",
                conceptTag: GoConcept.stringRunes
            ),
        ]
    )
}
