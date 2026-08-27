import Foundation

/// Unit A — declarations, zero values, functions, control flow.
enum CourseUnitCore {
    static let unit = CourseUnit(
        id: "core",
        title: "Go core",
        summary: "Declarations, zero values, multiple returns and the shapes Go repeats everywhere.",
        translationNote: """
        Most of this unit is not new material — it is unlearning. Go has no \
        constructors, no exceptions and no uninitialised memory, so habits from \
        Java, C# and Python each need one specific adjustment rather than a \
        general rewrite.
        """,
        lessons: [
            zeroValues, shortDeclaration, multipleReturns, unusedIsAnError,
            constantsAndIota, switchWithoutBreak, conversionsAreExplicit,
        ]
    )

    static let zeroValues = Lesson(
        id: "core.zero-values",
        title: "Nothing is uninitialised",
        objective: "Predict the value of any declared variable before it is assigned.",
        explanation: """
        Every Go variable starts at its type's zero value: 0 for numbers, "" \
        for strings, false for bools, and nil for pointers, slices, maps, \
        channels, functions and interfaces. There is no undefined and no \
        garbage memory, which is why Go code so often declares a variable and \
        uses it immediately without an assignment.

        The consequence worth internalising: a struct is usable the moment it \
        is declared. That is why Go rarely needs a constructor, and why the \
        idiomatic New function exists only when the zero value would be wrong.
        """,
        conceptTags: [GoConcept.varsUnused],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Counter struct {
            \tTotal int
            \tLabel string
            \tTags  []string
            }

            func main() {
            \tvar c Counter
            \tfmt.Printf("%d %q %v %d\\n", c.Total, c.Label, c.Tags == nil, len(c.Tags))
            }
            """,
            question: "What does this print, and why does len work on a nil slice?",
            answer: """
            0 "" true 0

            The zero value of a slice is nil, and len of a nil slice is 0. \
            Reading a nil slice is fine; only writing to one is not.
            """
        ),
        idiomaticSolution: nil
    )

    static let shortDeclaration = Lesson(
        id: "core.short-declaration",
        title: ":= declares, = assigns",
        objective: "Choose between := and = without guessing, and know when := is illegal.",
        explanation: """
        := declares and assigns in one step, and it is only legal inside a \
        function. It also requires at least one new variable on the left: \
        reusing it with all-existing names is the "no new variables" error.

        In a multiple assignment, := happily mixes new and existing names, \
        which is exactly what makes the err pattern read well: err is reused \
        while the value beside it is new each time.
        """,
        conceptTags: [GoConcept.shortDeclaration],
        task: .guidedTyping(
            target: """
            value, err := parse(input)
            if err != nil {
            \treturn err
            }
            """
        ),
        idiomaticSolution: nil
    )

    static let multipleReturns = Lesson(
        id: "core.multiple-returns",
        title: "Two returns instead of one exception",
        objective: "Write a function that returns a result and an error, and read one.",
        explanation: """
        Go functions return several values, and the last one is an error by \
        convention. This replaces exceptions entirely: there is no invisible \
        control flow, and every failure appears at the call site as a value \
        somebody has to handle.

        Coming from a language with exceptions, the surprise is how much of \
        the function body ends up being error handling — and that this is the \
        point. The cost is visible instead of hidden.
        """,
        conceptTags: [GoConcept.explicitErrorCheck, GoConcept.missingReturn],
        task: .compile(
            starter: """
            package main

            import (
            \t"errors"
            \t"fmt"
            )

            // half returns n divided by two, and an error when n is odd.
            func half(n int) (int, error) {
            \t// TODO: return an error when n is odd, otherwise the halved value.
            \treturn 0, nil
            }

            func main() {
            \tvalue, err := half(9)
            \tfmt.Println(value, err)
            }

            var errOdd = errors.New("value is odd")
            """,
            hiddenTest: """
            package main

            import (
            \t"errors"
            \t"testing"
            )

            func TestHalfEven(t *testing.T) {
            \tgot, err := half(8)
            \tif err != nil {
            \t\tt.Fatalf("half(8) returned %v", err)
            \t}
            \tif got != 4 {
            \t\tt.Errorf("half(8) = %d, want 4", got)
            \t}
            }

            func TestHalfOdd(t *testing.T) {
            \tif _, err := half(9); err == nil {
            \t\tt.Fatal("half(9) returned no error")
            \t}
            \tif _, err := half(9); !errors.Is(err, errOdd) {
            \t\tt.Errorf("half(9) error = %v, want errOdd", err)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func half(n int) (int, error) {
        \tif n%2 != 0 {
        \t\treturn 0, fmt.Errorf("half %d: %w", n, errOdd)
        \t}
        \treturn n / 2, nil
        }
        """
    )

    static let unusedIsAnError = Lesson(
        id: "core.unused-is-an-error",
        title: "An unused variable stops the build",
        objective: "Recognise the two unused errors on sight and know why they exist.",
        explanation: """
        Go refuses to compile a function with a variable it never reads, and a \
        file with an import it never uses. Not a warning — an error.

        This feels hostile for about a week. What it buys is that dead code \
        cannot accumulate quietly, and that a half-finished edit fails loudly \
        instead of shipping. The escape hatch when you genuinely need it is \
        assignment to _, which says "deliberately discarded" out loud.
        """,
        conceptTags: [GoConcept.varsUnused, GoConcept.unusedImport],
        task: .compile(
            starter: """
            package main

            import (
            \t"fmt"
            \t"os"
            )

            func main() {
            \thost := "localhost"
            \tport := 8080
            \tfmt.Println(port)
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            // The lesson passes when the package compiles at all: the starter
            // has both an unused variable and an unused import.
            func TestCompiles(t *testing.T) {}
            """
        ),
        idiomaticSolution: """
        package main

        import "fmt"

        func main() {
        \thost := "localhost"
        \tport := 8080
        \tfmt.Println(host, port)
        }
        """
    )
}
