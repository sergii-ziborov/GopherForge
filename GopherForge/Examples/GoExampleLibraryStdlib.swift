import Foundation

/// Examples for the parts of the standard library people reach for first.
enum GoExampleLibraryStdlib {
    static let all: [GoExample] = [readerInterface, jsonRoundTrip, scannerLines, sortSlice]

    static let readerInterface = GoExample(
        id: "std.reader",
        title: "One method, and everything accepts it",
        summary: "io.Reader is a single Read method, so anything can be one.",
        takeaway: "Write against io.Reader and a file, a network socket and a string all fit.",
        conceptTags: [GoConcept.stdlibIO, GoConcept.smallInterface],
        source: """
        package main

        import (
        \t"fmt"
        \t"io"
        \t"strings"
        )

        // Nothing here knows or cares where the bytes come from.
        func countBytes(r io.Reader) (int, error) {
        \tdata, err := io.ReadAll(r)
        \treturn len(data), err
        }

        func main() {
        \tn, err := countBytes(strings.NewReader("from a string"))
        \tfmt.Println(n, err)

        \tn, err = countBytes(io.LimitReader(strings.NewReader("truncated here"), 9))
        \tfmt.Println(n, err)
        }
        """,
        expectedOutput: """
        13 <nil>
        9 <nil>

        """
    )

    static let jsonRoundTrip = GoExample(
        id: "std.json",
        title: "JSON in and out of a struct",
        summary: "Tags decide the names; Unmarshal fills a value you pass by pointer.",
        takeaway: "A field the JSON does not mention keeps its zero value, silently.",
        conceptTags: [GoConcept.stdlibJSON],
        source: """
        package main

        import (
        \t"encoding/json"
        \t"fmt"
        )

        type Project struct {
        \tName  string `json:"name"`
        \tStars int    `json:"stars"`
        \t// Unexported fields are invisible to encoding/json entirely.
        \tnotes string
        }

        func main() {
        \tvar p Project
        \tif err := json.Unmarshal([]byte(`{"name":"forge"}`), &p); err != nil {
        \t\tfmt.Println("error:", err)
        \t\treturn
        \t}
        \tfmt.Printf("%+v\\n", p)

        \tout, _ := json.Marshal(Project{Name: "forge", Stars: 7, notes: "ignored"})
        \tfmt.Println(string(out))
        }
        """,
        expectedOutput: """
        {Name:forge Stars:0 notes:}
        {"name":"forge","stars":7}

        """
    )

    static let scannerLines = GoExample(
        id: "std.scanner",
        title: "Read a stream a line at a time",
        summary: "bufio.Scanner handles the buffering and the line splitting.",
        takeaway: "Always check scanner.Err(): the loop ends on both EOF and failure.",
        conceptTags: [GoConcept.stdlibIO],
        source: """
        package main

        import (
        \t"bufio"
        \t"fmt"
        \t"strings"
        )

        func main() {
        \tinput := "alpha\\nbeta\\n\\ngamma\\n"
        \tscanner := bufio.NewScanner(strings.NewReader(input))

        \tcount := 0
        \tfor scanner.Scan() {
        \t\tline := scanner.Text()
        \t\tif line == "" {
        \t\t\tcontinue
        \t\t}
        \t\tcount++
        \t\tfmt.Printf("%d: %s\\n", count, line)
        \t}

        \tif err := scanner.Err(); err != nil {
        \t\tfmt.Println("read failed:", err)
        \t}
        }
        """,
        expectedOutput: """
        1: alpha
        2: beta
        3: gamma

        """
    )

    static let sortSlice = GoExample(
        id: "std.sort",
        title: "Sort by whatever you like",
        summary: "slices.SortFunc takes a comparison and sorts in place.",
        takeaway: "The comparison returns negative, zero or positive — not a bool.",
        conceptTags: [GoConcept.stdlibIO],
        source: """
        package main

        import (
        \t"cmp"
        \t"fmt"
        \t"slices"
        )

        type Release struct {
        \tName string
        \tYear int
        }

        func main() {
        \treleases := []Release{
        \t\t{"go1.22", 2024},
        \t\t{"go1.11", 2018},
        \t\t{"go1.21", 2023},
        \t}

        \tslices.SortFunc(releases, func(a, b Release) int {
        \t\treturn cmp.Compare(a.Year, b.Year)
        \t})

        \tfor _, r := range releases {
        \t\tfmt.Println(r.Year, r.Name)
        \t}
        }
        """,
        expectedOutput: """
        2018 go1.11
        2023 go1.21
        2024 go1.22

        """
    )
}
