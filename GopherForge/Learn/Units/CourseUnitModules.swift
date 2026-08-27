import Foundation

/// Unit E — packages, modules and the commands people keep re-reading.
enum CourseUnitModules {
    static let unit = CourseUnit(
        id: "modules",
        title: "Packages, modules and tooling",
        summary: "Import paths, go.mod, go test and go vet, without a search engine.",
        translationNote: """
        Go's survey found professionals repeatedly returning to documentation \
        for core go subcommands. That is not a knowledge gap so much as a model \
        gap: once the module, the import path and the package directory line up \
        in your head, the commands stop needing to be memorised.
        """,
        lessons: [
            importPathIsIdentity, exportedByCase, testsLiveNextToCode,
            packageNaming, initAndPackageState,
        ]
    )

    static let importPathIsIdentity = Lesson(
        id: "modules.import-path",
        title: "The import path is the module path plus the directory",
        objective: "Predict the import path of any package in a module.",
        explanation: """
        go.mod names the module, for example example.com/forge. A package in \
        the directory internal/build is then imported as \
        example.com/forge/internal/build. There is no separate registration \
        step and no name that can drift from the directory.

        Two rules fall out of this. internal/ is enforced by the compiler: only \
        code rooted at its parent may import it. And the last element of the \
        path is the default package name, which is why directories are singular \
        and lowercase.
        """,
        conceptTags: [GoConcept.importPath],
        task: .predict(
            source: """
            // go.mod
            module example.com/forge

            go 1.24

            // internal/build/build.go
            package build

            func Run() {}
            """,
            question: "How does cmd/forge/main.go import Run, and could a different module do the same?",
            answer: """
            import "example.com/forge/internal/build"

            No other module can. internal/ is compiler-enforced: only packages \
            rooted at example.com/forge may import it.
            """
        ),
        idiomaticSolution: nil
    )

    static let exportedByCase = Lesson(
        id: "modules.exported-by-case",
        title: "A capital letter is the access modifier",
        objective: "Control visibility without keywords, and name things accordingly.",
        explanation: """
        An identifier starting with an upper-case letter is visible outside its \
        package; anything else is not. There is no public, private or protected.

        Because the name carries the visibility, renaming is an API change, and \
        Go's naming conventions get unusually strict: no stuttering \
        (build.Runner, not build.BuildRunner), no Get prefix on getters, and \
        short names for short-lived variables.
        """,
        conceptTags: [GoConcept.smallInterface],
        task: .guidedTyping(
            target: """
            // Runner executes one build.
            type Runner struct {
            \tworkdir string
            }

            func NewRunner(workdir string) *Runner {
            \treturn &Runner{workdir: workdir}
            }
            """
        ),
        idiomaticSolution: nil
    )

    static let testsLiveNextToCode = Lesson(
        id: "modules.tests",
        title: "Tests are a file, not a framework",
        objective: "Write a table-driven test and run it locally.",
        explanation: """
        A test is a function named TestXxx taking *testing.T, in a file ending \
        _test.go, in the same package. No annotations, no runner \
        configuration, no dependency.

        The table-driven shape is the community default because it makes the \
        cases the data and the assertion the code, and t.Run gives each row its \
        own name in the output.
        """,
        conceptTags: [GoConcept.stdlibTesting],
        task: .compile(
            starter: """
            package main

            // Clamp returns value limited to the range low..high.
            func Clamp(value, low, high int) int {
            \treturn value
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestClamp(t *testing.T) {
            \tcases := []struct {
            \t\tname                  string
            \t\tvalue, low, high, want int
            \t}{
            \t\t{"inside", 5, 0, 10, 5},
            \t\t{"below", -3, 0, 10, 0},
            \t\t{"above", 42, 0, 10, 10},
            \t}
            \tfor _, c := range cases {
            \t\tt.Run(c.name, func(t *testing.T) {
            \t\t\tif got := Clamp(c.value, c.low, c.high); got != c.want {
            \t\t\t\tt.Errorf("Clamp(%d) = %d, want %d", c.value, got, c.want)
            \t\t\t}
            \t\t})
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Clamp(value, low, high int) int {
        \tif value < low {
        \t\treturn low
        \t}
        \tif value > high {
        \t\treturn high
        \t}
        \treturn value
        }
        """
    )
}
