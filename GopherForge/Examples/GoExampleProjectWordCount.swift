import Foundation

/// A tool split across packages, the way a Go program is actually laid out.
///
/// The lesson is the shape rather than the algorithm: a directory is a package,
/// `internal/` is private to the module, and the test sits beside the code it
/// tests.
enum GoExampleProjectWordCount {
    static let wordCount = GoExample(
        id: "project.wordcount",
        title: "Word count",
        summary: "A small tool split across packages, the way Go lays one out.",
        takeaway: "internal/ is private to the module — nothing outside it can import it.",
        conceptTags: [GoConcept.stdlibIO, GoConcept.stringRunes],
        source: """
        package main

        import (
        \t"fmt"
        \t"sort"
        \t"strings"

        \t"example.com/wordcount/internal/counter"
        )

        func main() {
        \ttext := `the quick brown fox jumps over the lazy dog
        the dog barks and the fox runs`

        \tcounts := counter.Count(strings.NewReader(text))

        \twords := make([]string, 0, len(counts))
        \tfor word := range counts {
        \t\twords = append(words, word)
        \t}
        \t// Sort by count, then alphabetically, so the output is stable.
        \tsort.Slice(words, func(i, j int) bool {
        \t\tif counts[words[i]] != counts[words[j]] {
        \t\t\treturn counts[words[i]] > counts[words[j]]
        \t\t}
        \t\treturn words[i] < words[j]
        \t})

        \tfor _, word := range words[:3] {
        \t\tfmt.Printf("%-6s %d\\n", word, counts[word])
        \t}
        \tfmt.Println("distinct:", len(counts))
        }
        """,
        expectedOutput: """
        the    4
        dog    2
        fox    2
        distinct: 11

        """,
        extraFiles: [
            "internal/counter/counter.go": """
            // Package counter tallies words from any reader.
            package counter

            import (
            \t"bufio"
            \t"io"
            \t"strings"
            )

            // Count returns how many times each word appears.
            func Count(r io.Reader) map[string]int {
            \tcounts := map[string]int{}
            \tscanner := bufio.NewScanner(r)
            \tscanner.Split(bufio.ScanWords)
            \tfor scanner.Scan() {
            \t\tcounts[strings.ToLower(scanner.Text())]++
            \t}
            \treturn counts
            }
            """,
            "internal/counter/counter_test.go": """
            package counter

            import (
            \t"strings"
            \t"testing"
            )

            func TestCount(t *testing.T) {
            \tcounts := Count(strings.NewReader("a b A"))
            \tif counts["a"] != 2 {
            \t\tt.Errorf("a = %d, want 2", counts["a"])
            \t}
            \tif counts["b"] != 1 {
            \t\tt.Errorf("b = %d, want 1", counts["b"])
            \t}
            }
            """,
        ],
        modulePath: "example.com/wordcount"
    )
}
