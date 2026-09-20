import Foundation

/// Authored hint and nuance for every lesson that shows code.
///
/// Realize does not live here: it applies `Lesson.verifiedSolution`, the same
/// program the gate compiles. A second copy of that program would drift.
enum LessonHintCatalog {
    static func hint(for lesson: Lesson) -> LessonHint {
        allAuthored[lesson.id] ?? synthesized(from: lesson)
    }

    static func realizeSource(for lesson: Lesson) -> String? {
        lesson.verifiedSolution
    }

    static var authoredIDs: Set<String> { Set(allAuthored.keys) }

    static func synthesized(from lesson: Lesson) -> LessonHint {
        LessonHint(
            lessonID: lesson.id,
            hint: "Edit the code until the check on this page agrees.",
            nuance: String(lesson.explanation.prefix(160))
        )
    }

    static let authored: [String: LessonHint] = Dictionary(
        uniqueKeysWithValues: (core + collections + structs).map { ($0.lessonID, $0) }
    )

    private static func entry(_ id: String, hint: String, nuance: String) -> LessonHint {
        LessonHint(lessonID: id, hint: hint, nuance: nuance)
    }

    // MARK: - Core

    private static let core: [LessonHint] = [
        entry("core.zero-values", hint: "Read each var before any assign. Name the zero of int, bool, string and a pointer.", nuance: "There is no uninitialised memory. nil is only for pointers, slices, maps, channels and interfaces."),
        entry("core.short-declaration", hint: "Type the line exactly. := cannot appear at package level.", nuance: "At least one name on the left must be new, or the compiler says no new variables."),
        entry("core.multiple-returns", hint: "Return the value and an error. Do not throw, do not wrap a bool success flag.", nuance: "The error is a value. Ignoring it with _ is how a failure becomes a plausible zero."),
        entry("core.unused-is-an-error", hint: "Use every local and every import, or delete them.", nuance: "There is no unused-variable warning. The compiler refuses the file."),
        entry("core.constants", hint: "iota counts from zero in the const block. The untyped constant has no size until used.", nuance: "1 << 62 as a const is fine; assigned to int32 it overflows. The type arrives at the use."),
        entry("core.switch", hint: "Write a switch with no expression. Do not put break at the end of a case.", nuance: "Go cases do not fall through. fallthrough is the rare keyword, not the default."),
        entry("core.conversions", hint: "Convert len(readings) to Celsius before dividing.", nuance: "int and Celsius are different types even when the bits match. The conversion is the point."),
        entry("core.named-results", hint: "Name quot and rem in the signature and use a naked return.", nuance: "The Tour says keep naked returns for short functions. In a long one they hide what leaves."),
        entry("core.defer-stack", hint: "Deferred calls run last-in first-out. Arguments are evaluated when defer is registered.", nuance: "defer fmt.Println(i) in a loop captures each i. A closure over a shared i does not."),
    ]

    // MARK: - Collections

    private static let collections: [LessonHint] = [
        entry("collections.length-capacity", hint: "len is what you may index. cap is what you may reslice into.", nuance: "make([]int, 0, 10) has room and is not indexable. make([]int, 10) is."),
        entry("collections.append-aliasing", hint: "Return a slice that does not share the caller's array after you write.", nuance: "append writes in place until cap is exceeded. Past cap it allocates and the alias silently ends."),
        entry("collections.map-zero-value", hint: "A missing key is the zero value. Incrementing it is how a counter starts.", nuance: "Writing to a nil map panics. make, or a literal, before the first write."),
        entry("collections.runes-not-bytes", hint: "range over a string yields runes. i is a byte offset, not a character index.", nuance: "len counts bytes. é is two. Convert to []rune when you mean characters."),
        entry("collections.iterators", hint: "yield returning false must stop the iterator.", nuance: "A range-over-func is a push loop. Breaking the for is yield returning false, not a channel close."),
        entry("collections.bounds", hint: "s[i] checks len. s[:n] checks cap.", nuance: "Indexing into unused capacity panics. Reslicing into it is how a slice grows back."),
        entry("collections.map-order", hint: "Collect keys and sort them. Do not range and hope.", nuance: "Map iteration order is randomised. Tests that assume an order flake."),
        entry("collections.strings-builder", hint: "Write into strings.Builder. Do not concatenate in a loop.", nuance: "Each + allocates. Builder keeps one buffer. Reset it if you reuse one."),
        entry("collections.make-and-new", hint: "make the map. new the int. Do not swap them.", nuance: "new(map[string]int) is a pointer to nil. Writing through it panics. make returns a usable map."),
        entry("collections.arrays", hint: "Return [3]int, not a slice. Copy the first three elements.", nuance: "[4]int and [3]int are different types. Assigning an array copies every element."),
        entry("collections.map-ok", hint: "Use _, ok := m[key]. A stored zero is present.", nuance: "elem := m[key] cannot tell missing from zero. delete of a missing key is a no-op."),
        entry("collections.nil-slice", hint: "var s []int is nil and append still works. []int{} is empty and not nil.", nuance: "JSON encodes nil as null and empty as []. Prefer len(s) == 0 unless the wire cares."),
        entry("collections.function-values", hint: "Call fn on each element and collect the results. fn is a value, not a method.", nuance: "The Tour: functions are values. The type is func(int) int, including the argument and the result."),
    ]

    // MARK: - Structs

    private static let structs: [LessonHint] = [
        entry("structs.literals", hint: "Use keyed fields. Width and Height, not a positional pair.", nuance: "A positional literal breaks the moment someone inserts a field. The zero fills what you omit."),
        entry("structs.methods", hint: "Add needs a pointer receiver or the increment dies on a copy.", nuance: "A value receiver is a copy. The method compiles, runs, and changes nothing the caller can see."),
        entry("structs.pointers", hint: "Take the address when you mean to change the original.", nuance: "A pointer is for sharing mutation, not for speed. Small structs are passed by value on purpose."),
        entry("structs.closures", hint: "Declare count inside Counter so each call gets its own.", nuance: "A closure captures the variable, not its value. Two closures over one count share writes."),
        entry("structs.escape", hint: "Returning &local is ordinary Go. The compiler moves it to the heap.", nuance: "There is no dangling stack pointer. Escape analysis is why NewFoo can return &Foo{}."),
    ]
}
