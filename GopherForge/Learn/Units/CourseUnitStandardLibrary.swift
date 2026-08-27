import Foundation

/// Unit G — the standard library patterns that replace most dependencies.
enum CourseUnitStandardLibrary {
    static let unit = CourseUnit(
        id: "stdlib",
        title: "Standard library patterns",
        summary: "io.Reader and io.Writer, encoding/json, and testing without a framework.",
        translationNote: """
        Go's survey lists getting more from the standard library as a top \
        friction. The reason is usually not missing knowledge of a package but \
        missing knowledge of two interfaces: once io.Reader and io.Writer click, \
        a surprising share of third-party code stops being necessary.

        Some of this unit runs against in-memory transports rather than real \
        sockets, because the sandbox has no network. The compilation and the \
        types are real; only the transport is simulated, and every lesson says \
        so where it applies.
        """,
        lessons: [
            readersAndWriters, jsonTags,
            timeAndDuration, sorting, contextInPractice,
        ]
    )

    static let readersAndWriters = Lesson(
        id: "stdlib.io",
        title: "Two interfaces, one method each",
        objective: "Write a function that works on a file, a socket, a string and a test buffer.",
        explanation: """
        io.Reader has Read. io.Writer has Write. Files, network connections, \
        HTTP bodies, gzip streams, strings.Reader and bytes.Buffer all satisfy \
        one or both.

        Accepting them instead of a concrete type is what makes Go code testable \
        without mocks: the test passes a bytes.Buffer and reads the result back.
        """,
        conceptTags: [GoConcept.stdlibIO, GoConcept.smallInterface],
        task: .compile(
            starter: """
            package main

            import (
            \t"os"
            \t"strings"
            )

            // WriteUpper copies src to dst, upper-cased. It should work with any
            // reader and writer, not just files.
            func WriteUpper(dst *os.File, src *strings.Reader) error {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"bytes"
            \t"strings"
            \t"testing"
            )

            func TestWriteUpper(t *testing.T) {
            \tvar out bytes.Buffer
            \tif err := WriteUpper(&out, strings.NewReader("go forge")); err != nil {
            \t\tt.Fatalf("WriteUpper returned %v", err)
            \t}
            \tif got := out.String(); got != "GO FORGE" {
            \t\tt.Errorf("out = %q, want %q", got, "GO FORGE")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func WriteUpper(dst io.Writer, src io.Reader) error {
        \tdata, err := io.ReadAll(src)
        \tif err != nil {
        \t\treturn fmt.Errorf("read: %w", err)
        \t}
        \tif _, err := io.WriteString(dst, strings.ToUpper(string(data))); err != nil {
        \t\treturn fmt.Errorf("write: %w", err)
        \t}
        \treturn nil
        }
        """
    )

    static let jsonTags = Lesson(
        id: "stdlib.json",
        title: "Struct tags are the JSON schema",
        objective: "Control field names, omit empties, and know what unmarshalling leaves untouched.",
        explanation: """
        encoding/json maps struct fields by name, and a tag overrides that. \
        Only exported fields are considered, which is the first thing that \
        catches people: a lower-case field is invisible to the encoder with no \
        error.

        Unmarshal leaves fields absent from the input untouched rather than \
        zeroing them, so decoding into a reused struct can silently keep old \
        values.
        """,
        conceptTags: [GoConcept.stdlibJSON],
        task: .predict(
            source: """
            package main

            import (
            \t"encoding/json"
            \t"fmt"
            )

            type Config struct {
            \tHost    string `json:"host"`
            \tPort    int    `json:"port,omitempty"`
            \tsecret  string
            }

            func main() {
            \tdata, _ := json.Marshal(Config{Host: "localhost", secret: "hidden"})
            \tfmt.Println(string(data))
            }
            """,
            question: "What is printed, and where did port and secret go?",
            answer: """
            {"host":"localhost"}

            port was zero and carries omitempty, so it is dropped. secret is \
            unexported, so encoding/json cannot see it at all — no tag would \
            change that.
            """
        ),
        idiomaticSolution: nil
    )
}
