import Foundation

/// A complete, compilable answer for every lesson that asks for code.
///
/// These exist to be *run*, not read: `LessonSolutionGateTests` compiles each
/// one against its lesson's hidden test and requires the test to pass. Without
/// that, a lesson can ship with a hidden test nothing can satisfy, and the only
/// person who ever finds out is a learner who concludes they are stupid.
///
/// It already earned itself: the select lesson's hidden test called
/// `waitFor(values, ctx)` while the lesson taught — and its own idiomatic
/// answer used — context first. Nothing could have passed it.
enum LessonSolutionCatalog {
    static func solution(for lessonID: String) -> String? {
        core[lessonID] ?? collections[lessonID] ?? rest[lessonID]
    }

    /// Lesson identifiers this catalog answers.
    static var coveredLessonIDs: Set<String> {
        Set(core.keys).union(collections.keys).union(rest.keys)
    }

    // MARK: - Core

    static let core: [String: String] = [
        "core.multiple-returns": """
        package main

        import (
        \t"errors"
        \t"fmt"
        )

        var errOdd = errors.New("value is odd")

        func half(n int) (int, error) {
        \tif n%2 != 0 {
        \t\treturn 0, fmt.Errorf("half %d: %w", n, errOdd)
        \t}
        \treturn n / 2, nil
        }

        func main() {
        \tvalue, err := half(9)
        \tfmt.Println(value, err)
        }
        """,

        "core.unused-is-an-error": """
        package main

        import "fmt"

        func main() {
        \thost := "localhost"
        \tport := 8080
        \tfmt.Println(host, port)
        }
        """,

        "core.switch": """
        package main

        func Classify(n int) string {
        \tswitch {
        \tcase n < 10:
        \t\treturn "small"
        \tcase n < 100:
        \t\treturn "medium"
        \tdefault:
        \t\treturn "large"
        \t}
        }

        func main() {}
        """,

        "core.conversions": """
        package main

        type Celsius float64

        func Average(readings []Celsius) Celsius {
        \tvar sum Celsius
        \tfor _, r := range readings {
        \t\tsum += r
        \t}
        \treturn sum / Celsius(len(readings))
        }

        func main() {}
        """,
    ]

    // MARK: - Collections

    static let collections: [String: String] = [
        "collections.append-aliasing": """
        package main

        func window(s []int) []int {
        \treturn s[1:3:3]
        }

        func main() {}
        """,

        "collections.map-zero-value": """
        package main

        func countWords(words []string) map[string]int {
        \tcounts := make(map[string]int, len(words))
        \tfor _, word := range words {
        \t\tcounts[word]++
        \t}
        \treturn counts
        }

        func main() {}
        """,

        "collections.map-order": """
        package main

        import "slices"

        func SortedKeys(m map[string]int) []string {
        \tkeys := make([]string, 0, len(m))
        \tfor key := range m {
        \t\tkeys = append(keys, key)
        \t}
        \tslices.Sort(keys)
        \treturn keys
        }

        func main() {}
        """,

        "collections.strings-builder": """
        package main

        import "strings"

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

        func main() {}
        """,
    ]
}
