import Foundation

/// Two pages from A Tour of Go's basics and flow-control modules that the
/// core unit never taught: named results, and how deferred calls stack.
extension CourseUnitCore {
    static let namedResults = Lesson(
        id: "core.named-results",
        title: "A return can name what it is handing back",
        objective: "Write a short function that uses a naked return, and know when not to.",
        explanation: """
        A Tour of Go's "Named return values" page is the whole rule. The names \
        in the result list are variables declared at the top of the function. \
        A `return` with no arguments — a naked return — sends those variables \
        back. That is useful in a five-line helper whose results are `quot` \
        and `rem`. It is a liability in a longer function, because a bare \
        `return` no longer says what is leaving.

        The names are also documentation the compiler checks. `func Split(n, \
        d int) (quot, rem int)` tells a caller which number is which without \
        a comment, and a later `return` cannot silently swap them.
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
        The Tour's "Stacking defers" page is one sentence that people forget: \
        deferred calls are pushed onto a stack, and they run last-in, \
        first-out when the function returns. Three `defer fmt.Println(n)` \
        lines print in reverse order of how they were written.

        Arguments are evaluated when the defer is registered, not when it \
        runs. `defer fmt.Println(i)` inside a loop captures each i as it \
        was, which is why a loop of defers is safe and a loop of closures \
        over a shared i is not.
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
