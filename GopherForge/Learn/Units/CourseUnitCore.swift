import Foundation

/// Unit A — declarations, zero values, functions, control flow.
enum CourseUnitCore {
    static let unit = CourseUnit(
        id: "core",
        title: "Go core",
        summary: "Declarations, zero values, multiple returns and the shapes Go repeats everywhere.",
        translationNote: """
        Most of this unit is not new material — it is unlearning. Go has no \
        built-in class constructors or exception-handling syntax, and declared \
        variables start with zero values, so habits from \
        Java, C# and Python each need one specific adjustment rather than a \
        general rewrite.
        """,
        lessons: [
            zeroValues, shortDeclaration, multipleReturns, unusedIsAnError,
            constantsAndIota, switchWithoutBreak, conversionsAreExplicit,
            namedResults, stackingDefers,
        ]
    )

    static let zeroValues = Lesson(
        id: "core.zero-values",
        title: "Nothing is uninitialised",
        objective: "Predict the value of any declared variable before it is assigned.",
        explanation: """
        Every Go variable starts at its type's zero value: `0` for numbers, `""` for strings, `false` for booleans, and `nil` for pointers, slices, maps, channels, functions and interfaces. A declaration gives you a defined value immediately.

        A struct starts with every field at its own zero value. Design that state to be useful when possible: counters and slices work naturally, while a map field still needs initialization before a write. A `New` function is useful when the type requires setup that its zero value cannot provide.
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

            The zero value of a slice is nil. Its length and capacity are 0. \
            You can range over it or append to it; append returns the resulting \
            slice. Indexing the empty slice to read or write an element is \
            out of bounds.
            """
        ),
        idiomaticSolution: nil
    )

    static let shortDeclaration = Lesson(
        id: "core.short-declaration",
        title: ":= declares, = assigns",
        objective: "Choose between := and = without guessing, and know when := is illegal.",
        explanation: """
        `:=` declares and assigns in one step inside a function. At least one non-blank name on the left must be new in the current block; otherwise the compiler reports "no new variables".

        A short declaration may mix new names with names already declared in that same block. Inside a nested block, however, it may introduce a different variable with the same spelling. Use `=` when the intention is to update an existing variable.
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
        Go functions can return several values. A common fallible signature returns a result followed by `error`; callers inspect that error before continuing with the result.

        This makes ordinary failures explicit at the call site instead of using exceptions. Go also has `panic` and `recover` for exceptional control flow, but an error result is the usual contract for an expected failure. Short failure branches keep the successful path easy to read.
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
