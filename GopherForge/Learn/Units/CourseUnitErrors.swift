import Foundation

/// Unit D — errors as values.
enum CourseUnitErrors {
    static let unit = CourseUnit(
        id: "errors",
        title: "Errors",
        summary: "Wrapping, errors.Is and errors.As, sentinels, defer and the panic boundary.",
        translationNote: """
        There is no catch. An error is a value you return, and the caller \
        decides. What replaces a stack trace is a chain of wrapped context, \
        built deliberately at each level that knows something the level below \
        did not.
        """,
        lessons: [wrapWithContext, isAndAs, deferOrder, customErrorType, panicIsNotAnError]
    )

    static let wrapWithContext = Lesson(
        id: "errors.wrapping",
        title: "%w adds context without hiding the cause",
        objective: "Wrap an error so callers can still match the original.",
        explanation: """
        fmt.Errorf with %w produces an error that both reads well and still \
        contains the original. errors.Is and errors.As walk that chain.

        Two conventions make the chain readable: error strings are lowercase \
        and unpunctuated because they get concatenated, and each layer adds \
        only what it uniquely knows — usually the operation and its input.
        """,
        conceptTags: [GoConcept.errorWrapping],
        task: .compile(
            starter: """
            package main

            import (
            \t"errors"
            \t"strconv"
            )

            var ErrNotANumber = errors.New("not a number")

            // parsePort should report which input failed and still let callers
            // match ErrNotANumber.
            func parsePort(raw string) (int, error) {
            \tn, err := strconv.Atoi(raw)
            \tif err != nil {
            \t\treturn 0, ErrNotANumber
            \t}
            \treturn n, nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"errors"
            \t"strings"
            \t"testing"
            )

            func TestParsePortWraps(t *testing.T) {
            \t_, err := parsePort("http")
            \tif !errors.Is(err, ErrNotANumber) {
            \t\tt.Fatalf("error %v does not match ErrNotANumber", err)
            \t}
            \tif !strings.Contains(err.Error(), "http") {
            \t\tt.Errorf("error %q does not mention the input", err)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func parsePort(raw string) (int, error) {
        \tn, err := strconv.Atoi(raw)
        \tif err != nil {
        \t\treturn 0, fmt.Errorf("parse port %q: %w", raw, ErrNotANumber)
        \t}
        \treturn n, nil
        }
        """
    )

    static let isAndAs = Lesson(
        id: "errors.is-and-as",
        title: "Is compares, As extracts",
        objective: "Choose between errors.Is and errors.As without trial and error.",
        explanation: """
        errors.Is asks whether anything in the chain equals a sentinel. \
        errors.As asks whether anything in the chain is a particular type, and \
        gives it to you so you can read its fields.

        Sentinel when the caller only needs to know which kind of failure it \
        was; typed error when the caller needs a detail, such as which field \
        was invalid.
        """,
        conceptTags: [GoConcept.errorSentinel, GoConcept.errorWrapping],
        task: .guidedTyping(
            target: """
            var invalid *ValidationError
            if errors.As(err, &invalid) {
            \treturn invalid.Field
            }
            """
        ),
        idiomaticSolution: nil
    )

    static let deferOrder = Lesson(
        id: "errors.defer",
        title: "defer runs last in, first out",
        objective: "Release what you acquired, in the right order, on every path.",
        explanation: """
        A deferred call runs when the function returns, whichever return it \
        was, and deferred calls run in reverse order. That is what makes \
        acquire-then-defer-release safe against every early return an error \
        check introduces.

        The argument to a deferred call is evaluated immediately; only the call \
        is postponed. This surprises people exactly once.
        """,
        conceptTags: [GoConcept.deferCleanup],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \tfor i := 1; i <= 3; i++ {
            \t\tdefer fmt.Print(i, " ")
            \t}
            \tfmt.Print("end ")
            }
            """,
            question: "In what order do the numbers print?",
            answer: """
            end 3 2 1

            Each defer captured its own i by value at the moment it was \
            deferred, and the deferred calls run in reverse order.
            """
        ),
        idiomaticSolution: nil
    )
}
