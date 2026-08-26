import Foundation

/// Unit B — slices, maps, strings.
enum CourseUnitCollections {
    static let unit = CourseUnit(
        id: "collections",
        title: "Slices, maps and strings",
        summary: "Length against capacity, shared backing arrays, and why a string is not a []char.",
        translationNote: """
        This is where habits from Python and JavaScript do real damage. A Go \
        slice is a view over an array, not a list object, so two slices can \
        share memory and a third can silently observe your writes.
        """,
        lessons: [lengthAndCapacity, appendAliasing, mapZeroValue, runesNotBytes]
    )

    static let lengthAndCapacity = Lesson(
        id: "collections.length-capacity",
        title: "len is what you have, cap is what you can grow into",
        objective: "Predict when append allocates and when it writes in place.",
        explanation: """
        A slice is three words: a pointer to an array, a length and a capacity. \
        append writes into the existing array while the capacity allows it, and \
        allocates a new one when it does not.

        That single rule explains most slice surprises: whether a write is seen \
        by another slice depends on whether an append happened to reallocate.
        """,
        conceptTags: [GoConcept.sliceCapacity],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \ts := make([]int, 0, 4)
            \ts = append(s, 1, 2)
            \tfmt.Println(len(s), cap(s))
            \ts = append(s, 3, 4, 5)
            \tfmt.Println(len(s), cap(s))
            }
            """,
            question: "What are the two length and capacity pairs?",
            answer: """
            2 4, then 5 8.

            The first append fits in the capacity that was already reserved. \
            The second exceeds it, so the runtime allocates a larger array — \
            the growth factor is an implementation detail, but the doubling to \
            8 is what current Go does for small slices.
            """
        ),
        idiomaticSolution: nil
    )

    static let appendAliasing = Lesson(
        id: "collections.append-aliasing",
        title: "Two slices, one array",
        objective: "Spot the moment a subslice starts sharing writes with its parent.",
        explanation: """
        Slicing does not copy. s[1:3] points into the same array as s, so a \
        write through one is visible through the other — until an append \
        reallocates and quietly ends the sharing.

        The idiom that avoids the whole class of bugs is a full slice \
        expression, s[1:3:3], which caps the capacity so any append must copy.
        """,
        conceptTags: [GoConcept.sliceAliasing, GoConcept.sliceCapacity],
        task: .compile(
            starter: """
            package main

            // window returns the middle of s without letting the caller's
            // appends overwrite the rest of s.
            func window(s []int) []int {
            \treturn s[1:3]
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestWindowDoesNotShareCapacity(t *testing.T) {
            \toriginal := []int{1, 2, 3, 4, 5}
            \tw := window(original)
            \tw = append(w, 99)
            \tif original[3] == 99 {
            \t\tt.Fatal("append through the window overwrote the parent slice")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func window(s []int) []int {
        \treturn s[1:3:3]
        }
        """
    )

    static let mapZeroValue = Lesson(
        id: "collections.map-zero-value",
        title: "Reading a missing key is fine, writing to a nil map is not",
        objective: "Use comma-ok, and know which map operation panics.",
        explanation: """
        Reading a key that is absent returns the value type's zero value, with \
        no error. That is why comma-ok exists: v, ok := m[k] distinguishes \
        "absent" from "present and zero".

        The asymmetry to remember: reading from a nil map is legal and returns \
        zero values, but writing to one panics. A map must be made before it \
        can be written.
        """,
        conceptTags: [GoConcept.mapZeroValue],
        task: .compile(
            starter: """
            package main

            // countWords returns how many times each word appears.
            func countWords(words []string) map[string]int {
            \tvar counts map[string]int
            \tfor _, word := range words {
            \t\tcounts[word]++
            \t}
            \treturn counts
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestCountWords(t *testing.T) {
            \tgot := countWords([]string{"go", "go", "forge"})
            \tif got["go"] != 2 || got["forge"] != 1 {
            \t\tt.Errorf("counts = %v", got)
            \t}
            \tif got["absent"] != 0 {
            \t\tt.Errorf("missing key returned %d, want 0", got["absent"])
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func countWords(words []string) map[string]int {
        \tcounts := make(map[string]int, len(words))
        \tfor _, word := range words {
        \t\tcounts[word]++
        \t}
        \treturn counts
        }
        """
    )

    static let runesNotBytes = Lesson(
        id: "collections.runes-not-bytes",
        title: "A string is bytes; range gives you runes",
        objective: "Index, slice and iterate a string without corrupting characters.",
        explanation: """
        A Go string is an immutable sequence of bytes, usually UTF-8. s[i] is a \
        byte, not a character, and len(s) counts bytes.

        range is the exception: iterating a string yields runes with their byte \
        offsets, decoding UTF-8 as it goes. So range is safe for characters and \
        indexing is not.
        """,
        conceptTags: [GoConcept.stringRunes],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \ts := "héllo"
            \tfmt.Println(len(s), len([]rune(s)))
            \tfor i, r := range s {
            \t\tif i < 3 {
            \t\t\tfmt.Printf("%d:%c ", i, r)
            \t\t}
            \t}
            \tfmt.Println()
            }
            """,
            question: "Why do the two lengths differ, and which byte offsets appear?",
            answer: """
            6 5, then 0:h 1:é.

            é is two bytes in UTF-8, so the byte length is one more than the \
            rune count, and the offset after é jumps from 1 to 3.
            """
        ),
        idiomaticSolution: nil
    )
}
