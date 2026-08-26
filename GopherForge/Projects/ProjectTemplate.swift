import Foundation

/// The starting points offered on the new-project screen.
///
/// Every template builds and runs offline with the bundled standard library
/// alone. None of them declares a requirement, because a template that cannot
/// build on a plane would be a bad first impression of the product.
struct ProjectTemplate: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let systemImage: String
    let entryFile: String
    let files: [String: String]

    func project(named name: String) -> GopherForgeProject {
        var materialised = files
        let modulePath = ProjectTemplate.modulePath(for: name)
        materialised["go.mod"] = GoModule.minimal(modulePath: modulePath).rendered()
        return GopherForgeProject(
            name: name,
            files: materialised,
            entryFile: entryFile,
            provenance: .template()
        )
    }

    /// Module paths are not free-form: `go mod init` rejects spaces and upper
    /// case, so a display name is normalised rather than passed through.
    static func modulePath(for name: String) -> String {
        let allowed = name.lowercased().map { character -> Character in
            character.isLetter || character.isNumber || character == "-" ? character : "-"
        }
        let collapsed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "gopherforge-project" : collapsed
    }
}

extension ProjectTemplate {
    static let all: [ProjectTemplate] = [commandLineTool, tabularReport, workerPool, testedPackage]

    static let commandLineTool = ProjectTemplate(
        id: "cli",
        title: "Command-line tool",
        summary: "Flags, arguments and stdout, the shape most Go programs start as.",
        systemImage: "terminal",
        entryFile: "main.go",
        files: [
            "main.go": """
            package main

            import (
            \t"flag"
            \t"fmt"
            \t"strings"
            )

            func main() {
            \tname := flag.String("name", "gopher", "who to greet")
            \tloud := flag.Bool("loud", false, "shout the greeting")
            \tflag.Parse()

            \tgreeting := fmt.Sprintf("hello, %s", *name)
            \tif *loud {
            \t\tgreeting = strings.ToUpper(greeting)
            \t}
            \tfmt.Println(greeting)
            }
            """,
        ]
    )

    static let tabularReport = ProjectTemplate(
        id: "report",
        title: "Tabular report",
        summary: "Structs, slices and text/tabwriter, without a single dependency.",
        systemImage: "tablecells",
        entryFile: "main.go",
        files: [
            "main.go": """
            package main

            import (
            \t"fmt"
            \t"os"
            \t"text/tabwriter"
            )

            type row struct {
            \tPackage string
            \tLines   int
            \tTested  bool
            }

            func main() {
            \trows := []row{
            \t\t{Package: "forge", Lines: 240, Tested: true},
            \t\t{Package: "lab", Lines: 96, Tested: false},
            \t}

            \twriter := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
            \tdefer writer.Flush()

            \tfmt.Fprintln(writer, "PACKAGE\\tLINES\\tTESTED")
            \tfor _, item := range rows {
            \t\tfmt.Fprintf(writer, "%s\\t%d\\t%t\\n", item.Package, item.Lines, item.Tested)
            \t}
            }
            """,
        ]
    )

    static let workerPool = ProjectTemplate(
        id: "worker-pool",
        title: "Worker pool",
        summary: "Goroutines, a jobs channel and a WaitGroup, closed by the sender.",
        systemImage: "arrow.triangle.branch",
        entryFile: "main.go",
        files: [
            "main.go": """
            package main

            import (
            \t"fmt"
            \t"sync"
            )

            func main() {
            \tjobs := make(chan int, 8)
            \tresults := make(chan int, 8)

            \tvar workers sync.WaitGroup
            \tfor worker := 1; worker <= 3; worker++ {
            \t\tworkers.Add(1)
            \t\tgo func(id int) {
            \t\t\tdefer workers.Done()
            \t\t\tfor job := range jobs {
            \t\t\t\tresults <- job * job
            \t\t\t}
            \t\t}(worker)
            \t}

            \tfor job := 1; job <= 5; job++ {
            \t\tjobs <- job
            \t}
            \tclose(jobs)

            \tworkers.Wait()
            \tclose(results)

            \tfor result := range results {
            \t\tfmt.Println(result)
            \t}
            }
            """,
        ]
    )

    static let testedPackage = ProjectTemplate(
        id: "tested-package",
        title: "Package with tests",
        summary: "A package, a table-driven test and go test, all running locally.",
        systemImage: "checkmark.seal",
        entryFile: "main.go",
        files: [
            "main.go": """
            package main

            import "fmt"

            func main() {
            \tfmt.Println(Reverse("gopher"))
            }
            """,
            "reverse.go": """
            package main

            // Reverse returns s with its runes in the opposite order. It works on
            // runes rather than bytes so multi-byte characters survive.
            func Reverse(s string) string {
            \trunes := []rune(s)
            \tfor i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
            \t\trunes[i], runes[j] = runes[j], runes[i]
            \t}
            \treturn string(runes)
            }
            """,
            "reverse_test.go": """
            package main

            import "testing"

            func TestReverse(t *testing.T) {
            \tcases := []struct {
            \t\tname string
            \t\tin   string
            \t\twant string
            \t}{
            \t\t{name: "ascii", in: "gopher", want: "rehpog"},
            \t\t{name: "empty", in: "", want: ""},
            \t\t{name: "multibyte", in: "héllo", want: "olléh"},
            \t}

            \tfor _, testCase := range cases {
            \t\tt.Run(testCase.name, func(t *testing.T) {
            \t\t\tif got := Reverse(testCase.in); got != testCase.want {
            \t\t\t\tt.Errorf("Reverse(%q) = %q, want %q", testCase.in, got, testCase.want)
            \t\t\t}
            \t\t})
            \t}
            }
            """,
        ]
    )
}
