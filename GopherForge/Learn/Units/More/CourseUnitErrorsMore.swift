import Foundation

/// Two more for errors: your own error type, and what panic is actually for.
extension CourseUnitErrors {
    static let customErrorType = Lesson(
        id: "errors.custom-type",
        title: "An error is any type with an Error method",
        objective: "Write an error that carries data the caller can read.",
        explanation: """
        `error` is an interface with one method, so anything with \
        `Error() string` is one. That is what makes an error able to carry \
        structured information: a field for the line that failed, the value \
        that was rejected, the operation that was attempted.

        `errors.As` is the counterpart to `errors.Is`. Where Is asks "is this \
        that particular error", As asks "is there an error of this type \
        anywhere in the chain, and if so give it to me" — which is how a caller \
        reads those fields back out after the error has been wrapped.
        """,
        conceptTags: [GoConcept.customError, GoConcept.errorWrapping],
        task: .compile(
            starter: """
            package main

            // ParseError should report which field failed and why, and
            // satisfy the error interface.
            type ParseError struct {
            \tField  string
            \tReason string
            }

            // Parse returns a *ParseError when field is empty.
            func Parse(field, value string) error {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"errors"
            \t"fmt"
            \t"testing"
            )

            func TestParseReportsTheField(t *testing.T) {
            \terr := Parse("", "x")
            \tif err == nil {
            \t\tt.Fatal("expected an error for an empty field")
            \t}

            \twrapped := fmt.Errorf("loading config: %w", err)
            \tvar parseError *ParseError
            \tif !errors.As(wrapped, &parseError) {
            \t\tt.Fatal("errors.As should find a *ParseError through the wrapping")
            \t}
            \tif parseError.Reason == "" {
            \t\tt.Error("the error should say why")
            \t}
            \tif err.Error() == "" {
            \t\tt.Error("Error() should return something")
            \t}
            \tif Parse("name", "ada") != nil {
            \t\tt.Error("a valid field should not be an error")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func (e *ParseError) Error() string {
        \treturn fmt.Sprintf("field %q: %s", e.Field, e.Reason)
        }

        func Parse(field, value string) error {
        \tif field == "" {
        \t\treturn &ParseError{Field: field, Reason: "name is empty"}
        \t}
        \treturn nil
        }
        """
    )

    static let panicIsNotAnError = Lesson(
        id: "errors.panic",
        title: "panic is for bugs, not for failures",
        objective: "Say which of two situations deserves a panic.",
        explanation: """
        A file that will not open is a failure: it is expected, the caller can \
        do something about it, and it is an error value. An index past the end \
        of a slice is a bug: the program's own logic is wrong, and continuing \
        would be worse than stopping. Go draws that line deliberately, and a \
        library that panics on bad input has drawn it in the wrong place.

        `recover` exists, and its honest use is narrow: stopping one request \
        from taking down a server, at the boundary, before returning an \
        ordinary error. It is not a catch block, and using it as one hides the \
        bug that caused it.
        """,
        conceptTags: [GoConcept.panicIsNotAnError, GoConcept.explicitErrorCheck],
        task: .predict(
            source: """
            package main

            import "fmt"

            func safe(work func()) (err error) {
            \tdefer func() {
            \t\tif r := recover(); r != nil {
            \t\t\terr = fmt.Errorf("recovered: %v", r)
            \t\t}
            \t}()
            \twork()
            \treturn nil
            }

            func main() {
            \tfmt.Println(safe(func() { fmt.Println("fine") }))
            \tfmt.Println(safe(func() { panic("bad state") }))
            }
            """,
            question: "What does this print? Note that err is a named return.",
            answer: """
            fine
            <nil>
            recovered: bad state
            """
        ),
        idiomaticSolution: nil
    )
}
