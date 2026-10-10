import Foundation

/// Three more for collections: bounds, map order, and building strings.
extension CourseUnitCollections {
    static let boundsVersusCapacity = Lesson(
        id: "collections.bounds",
        title: "len is what you may read; cap is what you may reslice",
        objective: "Say which of two similar-looking index expressions panics.",
        explanation: """
        A slice has both a length and a capacity, and they gate different \
        things. Indexing is checked against len: `s[i]` panics the moment i \
        reaches len, however much capacity remains behind it. Reslicing is \
        checked against cap: `s[:n]` is legal for any n up to cap, and that is \
        how a slice grows back into space it had already allocated.

        This is why `make([]int, 0, 10)` is not indexable at all and \
        `make([]int, 10)` is: the first has room for ten and holds none.
        """,
        conceptTags: [GoConcept.sliceBounds, GoConcept.sliceCapacity],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \ts := make([]int, 3, 8)
            \tfmt.Println(len(s), cap(s))

            \tgrown := s[:6]
            \tfmt.Println(len(grown), cap(grown))

            \tdefer func() {
            \t\tif r := recover(); r != nil {
            \t\t\tfmt.Println("panic on index")
            \t\t}
            \t}()
            \tfmt.Println(s[5])
            }
            """,
            question: "What does this print?",
            answer: """
            3 8
            6 8
            panic on index
            """
        ),
        idiomaticSolution: nil
    )

    static let mapsAreUnordered = Lesson(
        id: "collections.map-order",
        title: "Map iteration order is not specified",
        objective: "Produce stable output from a map without hoping.",
        explanation: """
        The language does not specify map iteration order, and the order may change from one iteration to the next. A small example that repeatedly uses one order does not establish a guarantee.

        When output must be deterministic, collect the keys, sort them and read values in that sorted order. When order is irrelevant, test the entries without requiring a particular traversal sequence.
        """,
        conceptTags: [GoConcept.mapOrder],
        task: .compile(
            starter: """
            package main

            // SortedKeys returns the map's keys in ascending order.
            func SortedKeys(m map[string]int) []string {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestSortedKeys(t *testing.T) {
            \tgot := SortedKeys(map[string]int{"c": 1, "a": 2, "b": 3})
            \twant := []string{"a", "b", "c"}

            \tif len(got) != len(want) {
            \t\tt.Fatalf("got %v, want %v", got, want)
            \t}
            \tfor i := range want {
            \t\tif got[i] != want[i] {
            \t\t\tt.Fatalf("got %v, want %v", got, want)
            \t\t}
            \t}
            \tif SortedKeys(nil) != nil && len(SortedKeys(nil)) != 0 {
            \t\tt.Error("an empty map should give an empty result")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func SortedKeys(m map[string]int) []string {
        \tkeys := make([]string, 0, len(m))
        \tfor key := range m {
        \t\tkeys = append(keys, key)
        \t}
        \tslices.Sort(keys)
        \treturn keys
        }
        """
    )

    static let buildingStrings = Lesson(
        id: "collections.strings-builder",
        title: "Concatenating in a loop repeatedly rebuilds a string",
        objective: "Use strings.Builder for repeated construction without rebuilding the prefix.",
        explanation: """
        Strings are immutable. Repeated `s += piece` operations in a growing loop can copy the accumulated prefix repeatedly, producing quadratic work as the output grows. Small fixed concatenations may be optimized differently, so measure the actual workload.

        `strings.Builder` accumulates text in a growing buffer and exposes the result with `String`. `strings.Join` is a simpler choice when all pieces are already collected. A non-zero Builder must not be copied.
        """,
        conceptTags: [GoConcept.stringsBuilder],
        task: .compile(
            starter: """
            package main

            // Repeat joins n copies of word with a single space between them.
            // Build it without concatenating in the loop.
            func Repeat(word string, n int) string {
            \tout := ""
            \tfor i := 0; i < n; i++ {
            \t\tout += word + " "
            \t}
            \treturn out
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestRepeat(t *testing.T) {
            \tif got := Repeat("go", 3); got != "go go go" {
            \t\tt.Errorf("Repeat = %q, want %q", got, "go go go")
            \t}
            \tif got := Repeat("go", 1); got != "go" {
            \t\tt.Errorf("Repeat = %q, want %q", got, "go")
            \t}
            \tif got := Repeat("go", 0); got != "" {
            \t\tt.Errorf("Repeat = %q, want empty", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Repeat(word string, n int) string {
        \tvar b strings.Builder
        \tfor i := 0; i < n; i++ {
        \t\tif i > 0 {
        \t\t\tb.WriteByte(' ')
        \t\t}
        \t\tb.WriteString(word)
        \t}
        \treturn b.String()
        }
        """
    )
}
