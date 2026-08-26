import Foundation

/// Unit C — interfaces without inheritance.
enum CourseUnitInterfaces {
    static let unit = CourseUnit(
        id: "interfaces",
        title: "Interfaces",
        summary: "Implicit satisfaction, method sets, and the nil that is not nil.",
        translationNote: """
        Nothing declares that it implements an interface. That inverts where \
        abstraction lives: the consumer defines the interface it needs, so the \
        useful interfaces are small and defined next to the code using them, \
        not next to the type satisfying them.
        """,
        lessons: [implicitSatisfaction, methodSets, nilInterface]
    )

    static let implicitSatisfaction = Lesson(
        id: "interfaces.implicit",
        title: "The consumer declares the interface",
        objective: "Write the smallest interface a function needs, at the call site.",
        explanation: """
        A type satisfies an interface by having the methods. There is no \
        implements keyword and no import relationship, so a package can accept \
        types that were written before its interface existed.

        The idiom that follows: accept interfaces, return structs. And keep the \
        interface as small as the function actually uses — one method is common \
        and two is already a design decision.
        """,
        conceptTags: [GoConcept.smallInterface],
        task: .compile(
            starter: """
            package main

            import "strings"

            // summarise should accept anything that can report its own length,
            // not just a strings.Builder.
            func summarise(b *strings.Builder) int {
            \treturn b.Len()
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            type fakeSized struct{ n int }

            func (f fakeSized) Len() int { return f.n }

            func TestSummariseAcceptsAnySized(t *testing.T) {
            \tif got := summarise(fakeSized{n: 7}); got != 7 {
            \t\tt.Errorf("summarise = %d, want 7", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        type sized interface {
        \tLen() int
        }

        func summarise(s sized) int {
        \treturn s.Len()
        }
        """
    )

    static let methodSets = Lesson(
        id: "interfaces.method-sets",
        title: "Pointer receiver, pointer method set",
        objective: "Predict whether a value or only a pointer satisfies an interface.",
        explanation: """
        A method with a value receiver belongs to both T and *T. A method with a \
        pointer receiver belongs only to *T.

        So if any method that satisfies an interface has a pointer receiver, a \
        plain value does not satisfy it — and the compiler says "does not \
        implement", often pointing at a line that looks obviously correct. The \
        fix is nearly always &value rather than changing the receiver.
        """,
        conceptTags: [GoConcept.methodSet],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Counter struct{ n int }

            func (c *Counter) Add()      { c.n++ }
            func (c Counter) Total() int { return c.n }

            type adder interface{ Add() }

            func main() {
            \tvar c Counter
            \tvar a adder = &c
            \ta.Add()
            \tfmt.Println(c.Total())
            }
            """,
            question: "Why must the assignment use &c, and what does this print?",
            answer: """
            1.

            Add has a pointer receiver, so it is in the method set of *Counter \
            only. `var a adder = c` would not compile.
            """
        ),
        idiomaticSolution: nil
    )

    static let nilInterface = Lesson(
        id: "interfaces.nil",
        title: "A nil pointer in an interface is not a nil interface",
        objective: "Explain why err != nil can be true when the error is nil.",
        explanation: """
        An interface value holds a type and a value. It is nil only when both \
        are. Assign a nil *MyError to an error variable and the interface holds \
        a type with a nil value — so err != nil is true and calling a method \
        may panic.

        This is why a function returns a concrete error type only through the \
        error interface, and why returning a typed nil is a bug rather than a \
        style choice.
        """,
        conceptTags: [GoConcept.nilInterface],
        task: .predict(
            source: """
            package main

            import "fmt"

            type PathError struct{ Path string }

            func (e *PathError) Error() string { return "bad path: " + e.Path }

            func find(name string) *PathError { return nil }

            func check(name string) error { return find(name) }

            func main() {
            \tfmt.Println(check("ok") == nil)
            }
            """,
            question: "Does this print true or false, and why?",
            answer: """
            false.

            check returns an error interface holding type *PathError with a nil \
            value, and an interface is nil only when its type is nil too. \
            Returning nil explicitly on the success path fixes it.
            """
        ),
        idiomaticSolution: """
        func check(name string) error {
        \tif err := find(name); err != nil {
        \t\treturn err
        \t}
        \treturn nil
        }
        """
    )
}
