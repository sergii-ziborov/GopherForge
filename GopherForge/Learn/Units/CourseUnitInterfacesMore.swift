import Foundation

/// Two more for interfaces: asking what is inside one, and embedding.
extension CourseUnitInterfaces {
    static let typeSwitch = Lesson(
        id: "interfaces.type-switch",
        title: "Asking an interface what it is holding",
        objective: "Read a value out of an interface without risking a panic.",
        explanation: """
        A type assertion has two forms and the difference matters. \
        `v := x.(int)` panics when x is not an int. `v, ok := x.(int)` never \
        panics: ok says whether it worked, and v is the zero value when it did \
        not. In anything that handles input you did not write, the two-value \
        form is the only one.

        A type switch is the same question asked about several types at once, \
        and it is how Go writes what other languages do with pattern matching \
        or a visitor.
        """,
        conceptTags: [GoConcept.typeAssertion],
        task: .compile(
            starter: """
            package main

            import "fmt"

            // Describe returns "int 7", "string go", "bool true" or
            // "unknown" for anything else. Use a type switch.
            func Describe(value any) string {
            \treturn ""
            }

            func main() { fmt.Println(Describe(7)) }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestDescribe(t *testing.T) {
            \tfor _, c := range []struct {
            \t\tin   any
            \t\twant string
            \t}{
            \t\t{7, "int 7"},
            \t\t{"go", "string go"},
            \t\t{true, "bool true"},
            \t\t{1.5, "unknown"},
            \t\t{nil, "unknown"},
            \t} {
            \t\tif got := Describe(c.in); got != c.want {
            \t\t\tt.Errorf("Describe(%v) = %q, want %q", c.in, got, c.want)
            \t\t}
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Describe(value any) string {
        \tswitch v := value.(type) {
        \tcase int:
        \t\treturn fmt.Sprintf("int %d", v)
        \tcase string:
        \t\treturn fmt.Sprintf("string %s", v)
        \tcase bool:
        \t\treturn fmt.Sprintf("bool %t", v)
        \tdefault:
        \t\treturn "unknown"
        \t}
        }
        """
    )

    static let embedding = Lesson(
        id: "interfaces.embedding",
        title: "Embedding is not inheritance",
        objective: "Predict which method runs when an embedded type has one too.",
        explanation: """
        Writing a type inside a struct without a field name embeds it, and its \
        methods are promoted to the outer type. It looks like inheritance and \
        is not: there is no virtual dispatch and no super. The outer type gets \
        a field it can reach through, and the promoted methods still run \
        against that inner value.

        The consequence people trip on: a method the outer type declares \
        shadows the promoted one for outside callers, but a promoted method \
        calling a sibling still calls the inner one. Go resolves this at \
        compile time by name, not at run time by receiver.
        """,
        conceptTags: [GoConcept.embedding, GoConcept.methodSet],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Base struct{ Name string }

            func (b Base) Describe() string { return "base " + b.Name }
            func (b Base) Greet() string    { return "hello from " + b.Describe() }

            type Loud struct{ Base }

            func (l Loud) Describe() string { return "LOUD " + l.Name }

            func main() {
            \tl := Loud{Base{Name: "ada"}}
            \tfmt.Println(l.Describe())
            \tfmt.Println(l.Greet())
            }
            """,
            question: "What does this print? Look carefully at the second line.",
            answer: """
            LOUD ada
            hello from base ada
            """
        ),
        idiomaticSolution: nil
    )
}
