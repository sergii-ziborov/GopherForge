import Foundation

/// Two pages from A Tour of Go's basics and flow-control modules that the
/// core unit never taught: named results, and how deferred calls stack.
extension CourseUnitCore {
    static let namedResults = Lesson(
        id: "core.named-results",
        title: "A return can name what it is handing back",
        objective: "Write a short function that uses a naked return, and know when not to.",
        explanation: """
        Names in a function's result list declare local result variables initialized to zero. A bare `return` returns their current values. In a short helper, names such as `quot` and `rem` can explain which result is which.

        An explicit `return quot, rem` is often easier to review once a function has branches. Result names document intent, but the compiler does not protect two same-typed results from being swapped. A deferred closure may change named results before the function returns to its caller.
        """,
        conceptTags: [GoConcept.namedResults, GoConcept.missingReturn],
        task: .compile(
            starter: """
            package main

            // Split returns n / d and n % d. Name the results and use a
            // naked return. Do not guard against d == 0; the test never
            // passes zero.
            func Split(n, d int) (int, int) {
            \treturn 0, 0
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestSplit(t *testing.T) {
            \tquot, rem := Split(17, 5)
            \tif quot != 3 || rem != 2 {
            \t\tt.Fatalf("Split(17, 5) = %d, %d; want 3, 2", quot, rem)
            \t}
            \tquot, rem = Split(-9, 4)
            \tif quot != -2 || rem != -1 {
            \t\tt.Fatalf("Split(-9, 4) = %d, %d; want -2, -1", quot, rem)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Split(n, d int) (quot, rem int) {
        \tquot = n / d
        \trem = n % d
        \treturn
        }
        """
    )

    /// Tour: "Stacking defers". A predict challenge — the order is the lesson.
    static let stackingDefers = Lesson(
        id: "core.defer-stack",
        title: "Deferred calls stack, last one first",
        objective: "Say the print order of three deferred calls.",
        explanation: """
        Deferred calls run in last-in, first-out order when the surrounding function returns. Three `defer fmt.Println(n)` statements execute in the reverse of their registration order.

        The deferred function and its arguments are evaluated when `defer` executes. A deferred closure, in contrast, may read a captured variable when it eventually runs. Keep that distinction clear when a variable changes between registration and return.
        """,
        conceptTags: [GoConcept.deferCleanup],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \tfmt.Println("counting")
            \tfor i := 0; i < 3; i++ {
            \t\tdefer fmt.Println(i)
            \t}
            \tfmt.Println("done")
            }
            """,
            question: "What does this print? The Tour's stacking-defers program.",
            answer: """
            counting
            done
            2
            1
            0
            """
        ),
        idiomaticSolution: nil
    )
}
