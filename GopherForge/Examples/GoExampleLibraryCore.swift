import Foundation

/// Examples for the language itself: slices, maps, strings, errors.
///
/// Each one prints something specific, because the output is the assertion:
/// the compiler gate runs every example and compares what it printed with what
/// this file says it prints.
enum GoExampleLibraryCore {
    static let all: [GoExample] = [sliceAliasing, mapZeroValue, runesAndBytes, errorWrapping, deferOrder]

    static let sliceAliasing = GoExample(
        id: "slice.aliasing",
        title: "A slice shares its array",
        summary: "Reslicing does not copy, and appending sometimes does.",
        takeaway: "b := a[1:3] writes through to a — until an append outgrows cap and moves it.",
        conceptTags: [GoConcept.sliceAliasing, GoConcept.sliceCapacity],
        source: """
        package main

        import "fmt"

        func main() {
        \ta := []int{1, 2, 3, 4}
        \tb := a[1:3]

        \tb[0] = 99
        \tfmt.Println("shared:", a)

        \t// cap(b) is 3, so this append still fits inside a's array.
        \tb = append(b, 100)
        \tfmt.Println("still shared:", a, "len", len(b), "cap", cap(b))

        \t// This one does not fit, so append allocates and the link is cut.
        \tb = append(b, 101)
        \tb[0] = -1
        \tfmt.Println("now separate:", a)
        }
        """,
        expectedOutput: """
        shared: [1 99 3 4]
        still shared: [1 99 3 100] len 3 cap 3
        now separate: [1 99 3 100]

        """
    )

    static let mapZeroValue = GoExample(
        id: "map.zero",
        title: "A missing key is not an error",
        summary: "Reading a key that is not there gives the zero value.",
        takeaway: "Use the two-value form when absent and zero mean different things.",
        conceptTags: [GoConcept.mapZeroValue],
        source: """
        package main

        import "fmt"

        func main() {
        \tscores := map[string]int{"ada": 3}

        \tfmt.Println("missing:", scores["nobody"])

        \tvalue, ok := scores["nobody"]
        \tfmt.Println("two-value:", value, ok)

        \t// Counting works without checking first, because += starts from zero.
        \tcounts := map[rune]int{}
        \tfor _, r := range "hello" {
        \t\tcounts[r]++
        \t}
        \tfmt.Println("l appears", counts['l'], "times")
        }
        """,
        expectedOutput: """
        missing: 0
        two-value: 0 false
        l appears 2 times

        """
    )

    static let runesAndBytes = GoExample(
        id: "strings.runes",
        title: "Strings are bytes, ranged as runes",
        summary: "len counts bytes; range yields runes at byte offsets.",
        takeaway: "Index a string and you get a byte. Range it and you get characters.",
        conceptTags: [GoConcept.stringRunes],
        source: """
        package main

        import "fmt"

        func main() {
        \ts := "héllo"

        \tfmt.Println("bytes:", len(s), "runes:", len([]rune(s)))

        \tfor i, r := range s {
        \t\tif i > 2 {
        \t\t\tbreak
        \t\t}
        \t\tfmt.Printf("at byte %d: %c\\n", i, r)
        \t}
        }
        """,
        expectedOutput: """
        bytes: 6 runes: 5
        at byte 0: h
        at byte 1: é

        """
    )

    static let errorWrapping = GoExample(
        id: "errors.wrapping",
        title: "Wrap an error, keep the original",
        summary: "%w adds context without hiding what actually failed.",
        takeaway: "errors.Is sees through wrapping; a formatted string does not.",
        conceptTags: [GoConcept.errorWrapping, GoConcept.errorSentinel],
        source: """
        package main

        import (
        \t"errors"
        \t"fmt"
        )

        var errNotFound = errors.New("not found")

        func load(name string) error {
        \treturn fmt.Errorf("load %q: %w", name, errNotFound)
        }

        func main() {
        \terr := load("config.json")

        \tfmt.Println(err)
        \tfmt.Println("is not found:", errors.Is(err, errNotFound))

        \t// Wrapped with %v instead, the original is gone.
        \tflat := fmt.Errorf("load: %v", errNotFound)
        \tfmt.Println("flat is not found:", errors.Is(flat, errNotFound))
        }
        """,
        expectedOutput: """
        load "config.json": not found
        is not found: true
        flat is not found: false

        """
    )

    static let deferOrder = GoExample(
        id: "errors.defer",
        title: "defer runs last, and in reverse",
        summary: "Cleanup happens however the function returns, newest first.",
        takeaway: "Arguments to a deferred call are evaluated immediately; the call is not.",
        conceptTags: [GoConcept.deferCleanup],
        source: """
        package main

        import "fmt"

        func main() {
        \tfor i := 1; i <= 3; i++ {
        \t\tdefer fmt.Println("deferred", i)
        \t}

        \tx := "before"
        \tdefer fmt.Println("captured at defer time:", x)
        \tx = "after"

        \tfmt.Println("body done, x is", x)
        }
        """,
        expectedOutput: """
        body done, x is after
        captured at defer time: before
        deferred 3
        deferred 2
        deferred 1

        """
    )
}
