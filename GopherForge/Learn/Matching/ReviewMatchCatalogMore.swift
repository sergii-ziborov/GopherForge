import Foundation

extension ReviewMatchCatalog {
    /// Every lesson and prediction contributes a pair. Previously the five
    /// generics lessons, among others, could never contribute to Review.
    static let additionalPairs: [MatchingPair] = [
        pair("core.switch", "switch without fallthrough", "Stops after the first matching case", GoConcept.switchNoFallthrough),
        pair("core.conversions", "int(x)", "An explicit conversion; it may discard a fraction", GoConcept.conversion),
        pair("core.defer-stack", "defer first(); defer second()", "second runs before first when the function returns", GoConcept.deferCleanup),
        pair("structs.closures", "A closure", "Keeps access to variables from its surrounding scope", GoConcept.closure, code: false),
        pair("structs.escape", "return &local", "Safe: Go keeps the referenced value alive", GoConcept.pointerReceiver),
        pair("collections.bounds", "s[i]", "i must be below len(s), even when cap(s) is larger", GoConcept.sliceBounds),
        pair("collections.map-order", "range over a map", "Its iteration order is unspecified", GoConcept.mapOrder, code: false),
        pair("collections.strings-builder", "strings.Builder", "Accumulates text without rebuilding the whole string", GoConcept.stringsBuilder),
        pair("collections.map-ok", "value, ok := m[key]", "ok distinguishes a missing key from a stored zero", GoConcept.mapCommaOK),
        pair("collections.nil-slice", "append(nilSlice, value)", "Works; keep the returned slice", GoConcept.sliceCapacity),
        pair("collections.function-values", "A function value", "Can be stored, passed and called like other values", GoConcept.functionValue, code: false),
        pair("interfaces.method-sets", "T versus *T method sets", "*T includes value and pointer receiver methods", GoConcept.methodSet, code: false),
        pair("interfaces.type-switch", "v, ok := x.(int)", "Reports a failed assertion without panicking", GoConcept.typeAssertion),
        pair("interfaces.embedding", "An embedded type", "Promotes methods; it does not add virtual dispatch", GoConcept.embedding, code: false),
        pair("generics.type-parameters", "func Keep[T any](in []T)", "T is a type argument checked at compile time", GoConcept.typeParameter),
        pair("generics.constraints", "~int | ~float64", "Allows types with either of those underlying types", GoConcept.constraint),
        pair("generics.containers", "Stack[string]", "A generic container instantiated for strings", GoConcept.typeParameter),
        pair("generics.when-not-to", "An ordinary interface parameter", "Fits behavior described only by a set of methods", GoConcept.genericsOveruse, code: false),
        pair("generics.methods", "A method's type parameter", "Names a type for that method's inputs or results", GoConcept.genericMethod, code: false),
        pair("errors.custom-type", "Error() string", "The method that makes a type implement error", GoConcept.customError),
        pair("errors.panic", "An expected input failure", "Return an error value rather than panic", GoConcept.panicIsNotAnError, code: false),
        pair("errors.recover", "recover() in a deferred call", "Can stop a panic in the same goroutine", GoConcept.panicIsNotAnError),
        pair("modules.tests", "func TestX(t *testing.T)", "A test function in a file ending in _test.go", GoConcept.stdlibTesting),
        pair("modules.naming", "http.Server, not http.HTTPServer", "Avoid repeating the package name in exported names", GoConcept.importPath, code: false),
        pair("modules.init", "Package initialization", "Imported packages initialize before their importers", GoConcept.packageInit, code: false),
        pair("concurrency.worker-pool", "wg.Wait()", "Waits for all work counted by the WaitGroup", GoConcept.waitGroup),
        pair("concurrency.once", "once.Do(f)", "Runs f at most once for that Once instance", GoConcept.syncOnce),
        pair("concurrency.range-and-close", "for v := range ch", "Receives until ch is closed and its buffer is drained", GoConcept.rangeOverChannel),
        pair("concurrency.select-default", "select with default", "Takes default immediately if no case can proceed", GoConcept.selectDefault, code: false),
        pair("stdlib.io", "io.Reader.Read", "Read returns a byte count and an error", GoConcept.stdlibIO),
        pair("stdlib.json", "json:\"name,omitempty\"", "A struct tag controlling a JSON field's encoding", GoConcept.stdlibJSON),
        pair("stdlib.time", "time.Duration", "An integer count of nanoseconds", GoConcept.stdlibTime),
        pair("stdlib.sort", "slices.SortFunc", "Uses a comparator to order slice elements", GoConcept.stdlibSort),
        pair("stdlib.context", "defer cancel()", "Releases resources for the derived context", GoConcept.contextCancel),
        MatchingPair(
            id: "review.core.short-scope", prompt: "Package-level :=",
            answer: "Not allowed; use var or const at package scope",
            conceptTag: GoConcept.shortDeclaration,
            requiredLessonID: "core.short-declaration"
        ),
        MatchingPair(
            id: "review.core.assignment", prompt: "x = 3",
            answer: "Assigns to an existing variable; no name is declared",
            conceptTag: GoConcept.shortDeclaration,
            requiredLessonID: "core.short-declaration", promptIsCode: true
        ),
        MatchingPair(
            id: "review.diagnostic.undefined", prompt: "undefined: name",
            answer: "The name is not declared or visible in this scope",
            conceptTag: GoConcept.undefinedSymbol,
            requiredLessonID: "modules.import-path"
        ),
        MatchingPair(
            id: "review.diagnostic.assignment", prompt: "var s string = n // n is int",
            answer: "Not assignable: int and string are different types",
            conceptTag: GoConcept.typeAssignment,
            requiredLessonID: "core.conversions", promptIsCode: true
        ),
        MatchingPair(
            id: "review.core.error-check", prompt: "if err != nil",
            answer: "Handle the error before using the returned result",
            conceptTag: GoConcept.explicitErrorCheck,
            requiredLessonID: "core.multiple-returns", promptIsCode: true
        ),
        MatchingPair(
            id: "review.core.unused-import", prompt: "imported and not used",
            answer: "An import no line in this file refers to",
            conceptTag: GoConcept.unusedImport,
            requiredLessonID: "core.unused-is-an-error"
        ),
        MatchingPair(
            id: "review.context.parameter", prompt: "func Work(ctx context.Context)",
            answer: "Pass a context as the first parameter, not a field",
            conceptTag: GoConcept.contextFirstParameter,
            requiredLessonID: "stdlib.context", promptIsCode: true
        ),
    ]

    private static func pair(
        _ lessonID: String, _ prompt: String, _ answer: String, _ tag: String,
        code: Bool = true
    ) -> MatchingPair {
        MatchingPair(
            id: "review.lesson.\(lessonID)", prompt: prompt, answer: answer,
            conceptTag: tag, requiredLessonID: lessonID, promptIsCode: code
        )
    }
}
