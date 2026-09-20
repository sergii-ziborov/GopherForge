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

    static let stringer = Lesson(
        id: "interfaces.stringer",
        title: "fmt looks for String(), not a Stringer keyword",
        objective: "Make a type print itself as a dotted IPv4 address.",
        explanation: """
        The Tour's "Stringers" page and its exercise are the same interface \
        the whole standard library uses:

            type Stringer interface { String() string }

        `fmt`, `log`, and the debugger call `String()` when a value has it. \
        There is no registration. The Tour exercise is `IPAddr [4]byte` \
        printing as `1.2.3.4` — a type that is not a string, describing \
        itself as one.

        Do not call `fmt.Sprint(v)` from `v`'s own `String` method. Sprint \
        looks for Stringer and you recurse until the stack blows. Convert \
        first, or format the fields yourself.
        """,
        conceptTags: [GoConcept.stringer, GoConcept.smallInterface],
        task: .compile(
            starter: """
            package main

            type IPAddr [4]byte

            // String should print 1.2.3.4 for IPAddr{1, 2, 3, 4}.
            func (ip IPAddr) String() string {
            \treturn ""
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"fmt"
            \t"testing"
            )

            func TestIPAddrStringer(t *testing.T) {
            \tgot := fmt.Sprint(IPAddr{1, 2, 3, 4})
            \tif got != "1.2.3.4" {
            \t\tt.Fatalf("Sprint = %q, want 1.2.3.4", got)
            \t}
            \tif (IPAddr{127, 0, 0, 1}).String() != "127.0.0.1" {
            \t\tt.Fatal("localhost should print 127.0.0.1")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func (ip IPAddr) String() string {
        \treturn fmt.Sprintf("%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3])
        }
        """
    )

    static let emptyInterface = Lesson(
        id: "interfaces.empty",
        title: "any is interface{}, and it has no methods",
        objective: "Report the dynamic type of a value held in any.",
        explanation: """
        The Tour's "The empty interface" page: `interface{}` specifies zero \
        methods, so every type implements it. `any` is the alias. \
        `fmt.Print` takes `...any` for that reason.

        Holding a value in `any` throws the static type away. Getting it \
        back is a type assertion or a type switch — the two-value form, or \
        you panic. `%T` in fmt is the cheap way to see what is inside, and \
        it is what this lesson asks you to return.
        """,
        conceptTags: [GoConcept.emptyInterface, GoConcept.typeAssertion],
        task: .compile(
            starter: """
            package main

            // Kind returns the dynamic type, as fmt would: "int", "string",
            // "*int". A nil any prints as <nil>.
            func Kind(value any) string {
            \treturn ""
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestKind(t *testing.T) {
            \tn := 3
            \tfor _, c := range []struct {
            \t\tin   any
            \t\twant string
            \t}{
            \t\t{7, "int"},
            \t\t{"go", "string"},
            \t\t{true, "bool"},
            \t\t{&n, "*int"},
            \t\t{nil, "<nil>"},
            \t} {
            \t\tif got := Kind(c.in); got != c.want {
            \t\t\tt.Errorf("Kind(%v) = %q, want %q", c.in, got, c.want)
            \t\t}
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Kind(value any) string {
        \treturn fmt.Sprintf("%T", value)
        }
        """
    )
}
