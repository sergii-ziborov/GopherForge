import Foundation

/// Three more for the core unit: constants, switch, and conversions.
///
/// Each one is a habit from another language that Go quietly refuses, and the
/// refusal is the lesson.
extension CourseUnitCore {
    static let constantsAndIota = Lesson(
        id: "core.constants",
        title: "Constants have no type until they need one",
        objective: "Explain why 1 << 40 compiles as a constant but overflows as an int32.",
        explanation: """
        An untyped constant in Go has arbitrary precision and no type until it \
        is used. `const big = 1 << 62` is fine even where an int is 32 bits, \
        because nothing has asked it to become an int yet. The moment it is \
        assigned or passed, it takes the type it is needed as — and that is \
        where it can fail to fit.

        `iota` is the other half. Inside a const block it counts from zero, one \
        step per line, which is how Go writes enumerations without an enum \
        keyword. The idiom is worth recognising on sight: a type, a const block \
        with iota, and often a String method.
        """,
        conceptTags: [GoConcept.constants],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Level int

            const (
            \tDebug Level = iota
            \tInfo
            \tWarn
            \tError
            )

            func main() {
            \tfmt.Println(Debug, Info, Warn, Error)
            \tconst big = 1 << 40
            \tfmt.Println(big / 1024 / 1024 / 1024)
            }
            """,
            question: "What does this print?",
            answer: """
            0 1 2 3
            1024
            """
        ),
        idiomaticSolution: nil
    )

    static let switchWithoutBreak = Lesson(
        id: "core.switch",
        title: "switch does not fall through",
        objective: "Write a Go switch without reaching for break.",
        explanation: """
        In C, Java and JavaScript a case runs on into the next one unless you \
        write `break`. Go inverted that: a case ends at the next case, and \
        `fallthrough` is the keyword you write on the rare occasion you want \
        the old behaviour. Every `break` in a Go switch is either a mistake or \
        a habit that has not been unlearned.

        Two more differences worth having: a case can list several values \
        separated by commas, and a switch with no expression is a tidy way to \
        write a chain of conditions.
        """,
        conceptTags: [GoConcept.switchNoFallthrough],
        task: .compile(
            starter: """
            package main

            // Classify returns "small" for n under 10, "medium" under 100,
            // and "large" otherwise. Write it with a switch that has no
            // expression after the keyword.
            func Classify(n int) string {
            \treturn ""
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestClassify(t *testing.T) {
            \tfor _, c := range []struct {
            \t\tin   int
            \t\twant string
            \t}{{0, "small"}, {9, "small"}, {10, "medium"}, {99, "medium"}, {100, "large"}} {
            \t\tif got := Classify(c.in); got != c.want {
            \t\t\tt.Errorf("Classify(%d) = %q, want %q", c.in, got, c.want)
            \t\t}
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let conversionsAreExplicit = Lesson(
        id: "core.conversions",
        title: "Go never converts a number for you",
        objective: "Fix a mismatched-type expression without guessing.",
        explanation: """
        There is no implicit numeric conversion in Go. An int and an int64 are \
        different types even where they are the same width, and adding them is \
        an error rather than a promotion. The fix is always an explicit \
        conversion, and the point of the rule is that the place where precision \
        could be lost is visible in the source.

        A named type behaves the same way. `type Celsius float64` cannot be \
        added to a float64 without saying so, which is exactly what makes named \
        types worth declaring: the compiler stops you mixing units.
        """,
        conceptTags: [GoConcept.typeAssignment, GoConcept.conversion],
        task: .compile(
            starter: """
            package main

            type Celsius float64

            // Average returns the mean of the readings, in Celsius.
            // count is an int and the sum is a Celsius; make them agree.
            func Average(readings []Celsius) Celsius {
            \tvar sum Celsius
            \tfor _, r := range readings {
            \t\tsum += r
            \t}
            \treturn sum / len(readings)
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestAverage(t *testing.T) {
            \tif got := Average([]Celsius{10, 20, 30}); got != 20 {
            \t\tt.Errorf("Average = %v, want 20", got)
            \t}
            \tif got := Average([]Celsius{1, 2}); got != 1.5 {
            \t\tt.Errorf("Average = %v, want 1.5", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        return sum / Celsius(len(readings))
        """
    )
}
