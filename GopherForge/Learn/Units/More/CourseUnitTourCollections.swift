import Foundation

/// Pages from A Tour of Go's "More types" module the collections unit skipped:
/// arrays, make versus new, the comma-ok map read, and the nil slice.
extension CourseUnitCollections {
    static let makeAndNew = Lesson(
        id: "collections.make-and-new",
        title: "make builds the header; new only allocates",
        objective: "Pick make or new for a slice, a map and a pointer.",
        explanation: """
        The Tour's "Creating a slice with make" page and Effective Go's \
        "Allocation with new" page are the same distinction. `new(T)` \
        allocates a zero T and returns `*T`. That is all it does. `make` is \
        only for slices, maps and channels: it allocates the backing store \
        and returns a usable value, not a pointer to one.

        `new(map[string]int)` is a pointer to a nil map. Writing through it \
        panics. `make(map[string]int)` is a map you can write. The same trap \
        exists for a slice: `new([]int)` is `*[]int` pointing at nil; \
        `make([]int, 0, 8)` is a slice with room.
        """,
        conceptTags: [GoConcept.makeVsNew, GoConcept.mapZeroValue],
        task: .compile(
            starter: """
            package main

            // ReadyMap must be writable. ZeroCounter must be a pointer to 0,
            // not a nil *int.
            func ReadyMap() map[string]int { return nil }
            func ZeroCounter() *int        { return nil }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestReadyMapIsWritable(t *testing.T) {
            \tm := ReadyMap()
            \tif m == nil {
            \t\tt.Fatal("ReadyMap returned nil; use make, not new")
            \t}
            \tm["hits"]++
            \tif m["hits"] != 1 {
            \t\tt.Fatalf("hits = %d, want 1", m["hits"])
            \t}
            }

            func TestZeroCounterPointsAtZero(t *testing.T) {
            \tp := ZeroCounter()
            \tif p == nil {
            \t\tt.Fatal("ZeroCounter returned nil")
            \t}
            \tif *p != 0 {
            \t\tt.Fatalf("*p = %d, want 0", *p)
            \t}
            \t*p = 4
            \tif *p != 4 {
            \t\tt.Fatalf("the pointer should be writable, *p = %d", *p)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func ReadyMap() map[string]int { return make(map[string]int) }
        func ZeroCounter() *int        { return new(int) }
        """
    )

    static let arraysVersusSlices = Lesson(
        id: "collections.arrays",
        title: "The length is part of an array's type",
        objective: "Write a function that takes [4]int and returns [3]int.",
        explanation: """
        The Tour's "Arrays" page is the one people skip because slices are \
        what you use. Then a function signature says `[32]byte` and the \
        compiler refuses a `[16]byte`. The length is in the type: `[4]int` \
        and `[3]int` are as different as `int` and `string`.

        An array is a value. Assigning it copies every element. A slice is a \
        header pointing at an array, which is why two slices can share memory \
        and two arrays never do unless you pass a pointer. The conversion is \
        one way and explicit: `s := a[:]` views the array; there is no implicit \
        `[n]T` from a slice of the wrong length.
        """,
        conceptTags: [GoConcept.arrays, GoConcept.sliceCapacity],
        task: .compile(
            starter: """
            package main

            // FirstThree returns the first three elements as an array, not
            // a slice. The length has to be in the type.
            func FirstThree(values [4]int) [3]int {
            \treturn [3]int{}
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestFirstThree(t *testing.T) {
            \tgot := FirstThree([4]int{9, 8, 7, 6})
            \twant := [3]int{9, 8, 7}
            \tif got != want {
            \t\tt.Fatalf("got %v, want %v", got, want)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func FirstThree(values [4]int) [3]int {
        \treturn [3]int{values[0], values[1], values[2]}
        }
        """
    )

    static let mapCommaOK = Lesson(
        id: "collections.map-ok",
        title: "Comma-ok is how you tell zero from missing",
        objective: "Report whether a key is present when its value can be zero.",
        explanation: """
        The Tour's "Mutating Maps" page is the two-value read: `elem, ok := \
        m[key]`. A missing key and a present zero look the same if you only \
        take `elem`. Scores, counts, flags — anything whose zero is a \
        legitimate stored value — need the ok.

        `delete(m, key)` is the other half of that page. Deleting a missing \
        key is a no-op, not an error. After delete, ok is false even if the \
        old value was zero.
        """,
        conceptTags: [GoConcept.mapCommaOK, GoConcept.mapZeroValue],
        task: .compile(
            starter: """
            package main

            // Has reports whether key is in m, even when m[key] is 0.
            func Has(m map[string]int, key string) bool {
            \treturn m[key] != 0
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestHasTellsZeroFromMissing(t *testing.T) {
            \tm := map[string]int{"zero": 0, "one": 1}
            \tif !Has(m, "zero") {
            \t\tt.Error("a stored zero is present")
            \t}
            \tif !Has(m, "one") {
            \t\tt.Error("one should be present")
            \t}
            \tif Has(m, "nope") {
            \t\tt.Error("a missing key is not present")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Has(m map[string]int, key string) bool {
        \t_, ok := m[key]
        \treturn ok
        }
        """
    )

    static let nilSlices = Lesson(
        id: "collections.nil-slice",
        title: "A nil slice is empty, and append still works",
        objective: "Predict what len, == nil and append do to a zero slice.",
        explanation: """
        The Tour's "Nil slices" page: the zero value of a slice is nil, it \
        has length and capacity 0, and it has no backing array. `append` \
        treats that as a valid empty slice and allocates. JSON encodes a nil \
        slice as `null` and a non-nil empty one as `[]` — the only common \
        place the distinction leaks out.

        `s == nil` is true for `var s []int` and false for `s := []int{}`. \
        Both have len 0. Prefer `len(s) == 0` unless you are talking to a \
        wire format that cares.
        """,
        conceptTags: [GoConcept.sliceCapacity],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \tvar s []int
            \tfmt.Println(s == nil, len(s), cap(s))
            \ts = append(s, 1)
            \tfmt.Println(s == nil, len(s), s[0])
            \tempty := []int{}
            \tfmt.Println(empty == nil, len(empty))
            }
            """,
            question: "What does this print?",
            answer: """
            true 0 0
            false 1 1
            false 0
            """
        ),
        idiomaticSolution: nil
    )

    static let functionValues = Lesson(
        id: "collections.function-values",
        title: "A function is a value you can pass",
        objective: "Apply a func(int) int to every element of a slice.",
        explanation: """
        The Tour's "Function values" page: functions are values. They can be \
        arguments and results. The type includes the parameters and the \
        result, so `func(int) int` and `func(int) string` are as different as \
        int and string.

        This is not a method and not a generic yet. It is the shape map and \
        filter had in Go before type parameters, and it is still how most \
        callbacks are written.
        """,
        conceptTags: [GoConcept.functionValue, GoConcept.closure],
        task: .compile(
            starter: """
            package main

            // Apply returns fn(v) for each v, in order.
            func Apply(values []int, fn func(int) int) []int {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestApply(t *testing.T) {
            \tgot := Apply([]int{1, 2, 3}, func(n int) int { return n * n })
            \tif len(got) != 3 || got[0] != 1 || got[2] != 9 {
            \t\tt.Fatalf("got %v, want [1 4 9]", got)
            \t}
            \tif len(Apply(nil, func(n int) int { return n })) != 0 {
            \t\tt.Fatal("empty in, empty out")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Apply(values []int, fn func(int) int) []int {
        \tout := make([]int, len(values))
        \tfor i, v := range values {
        \t\tout[i] = fn(v)
        \t}
        \treturn out
        }
        """
    )
}
