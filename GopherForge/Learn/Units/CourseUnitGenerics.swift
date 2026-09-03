import Foundation

/// Generics, which the course did not mention at all.
///
/// Go has had type parameters since 1.18. A Go course written as though it
/// still did not is teaching the language as it was in 2021, and the omission
/// shows up the first time somebody reads the `slices` package.
enum CourseUnitGenerics {
    static let unit = CourseUnit(
        id: "generics",
        title: "Generics, and when not to",
        summary: "Type parameters, constraints, and the times an interface is the better answer.",
        translationNote: """
        If you are coming from Java or C#, the shape will look familiar and the \
        culture will not. Go got type parameters late and on purpose, and the \
        community's default is still to reach for them last — a function that \
        works on one concrete type is not a failure waiting to be generalised.

        There is no reflection-based erasure story to learn and no covariance \
        rules to fight. A constraint is an interface, which means the thing you \
        already know does double duty: as a value's type, and as a bound on a \
        type parameter.
        """,
        lessons: [
            typeParameters,
            constraintsAreInterfaces,
            genericContainers,
            whenNotToUseThem,
        ]
    )

    static let typeParameters = Lesson(
        id: "generics.type-parameters",
        title: "A type parameter is written in square brackets",
        objective: "Write a function that works for several types without interface{} and without a cast.",
        explanation: """
        Type parameters go in square brackets before the ordinary ones: \
        `func Map[T, U any](in []T, f func(T) U) []U`. `T` and `U` are types \
        the caller supplies, and in almost every call the compiler infers them \
        so you write `Map(names, length)` with no brackets at all.

        `any` is the constraint that allows every type. It is a real alias for \
        `interface{}`, but in this position it means something different: with \
        `interface{}` as a *parameter* type you get a value you must assert \
        your way out of, and with `any` as a *constraint* you get the caller's \
        actual type, checked at compile time.

        That is the whole gain. The old version of this function returned \
        `[]interface{}` and every caller unpacked it; the generic one returns \
        `[]U`, and a mistake is a compile error rather than a panic.
        """,
        conceptTags: [GoConcept.typeParameter],
        task: .compile(
            starter: """
            package main

            // Keep should return a new slice holding the elements the predicate
            // returns true for, for any element type — no interface{} anywhere,
            // and the result keeps the caller's type.

            func main() {
            \teven := Keep([]int{1, 2, 3, 4}, func(n int) bool { return n%2 == 0 })
            \tprintln(len(even))
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestKeepOnInts(t *testing.T) {
            \tgot := Keep([]int{1, 2, 3, 4, 5}, func(n int) bool { return n%2 == 1 })
            \twant := []int{1, 3, 5}
            \tif len(got) != len(want) {
            \t\tt.Fatalf("Keep returned %v, want %v", got, want)
            \t}
            \tfor i := range want {
            \t\tif got[i] != want[i] {
            \t\t\tt.Fatalf("Keep returned %v, want %v", got, want)
            \t\t}
            \t}
            }

            // The point of the type parameter: this must compile, and the
            // result must already be []string with nothing to assert.
            func TestKeepOnStrings(t *testing.T) {
            \tgot := Keep([]string{"go", "", "forge"}, func(s string) bool { return s != "" })
            \tif len(got) != 2 || got[0] != "go" || got[1] != "forge" {
            \t\tt.Fatalf("Keep returned %v", got)
            \t}
            }

            func TestKeepOnEmpty(t *testing.T) {
            \tif got := Keep([]int{}, func(int) bool { return true }); len(got) != 0 {
            \t\tt.Errorf("Keep on an empty slice returned %v", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Keep[T any](in []T, keep func(T) bool) []T {
        \tvar out []T
        \tfor _, value := range in {
        \t\tif keep(value) {
        \t\t\tout = append(out, value)
        \t\t}
        \t}
        \treturn out
        }
        """
    )

    static let constraintsAreInterfaces = Lesson(
        id: "generics.constraints",
        title: "A constraint is an interface with types in it",
        objective: "Constrain a type parameter to what your code actually needs.",
        explanation: """
        A constraint says what the compiler may assume about `T`. It is written \
        as an interface — the same keyword — but an interface used as a \
        constraint can list *types* as well as methods:

        ```
        type Number interface {
        \t~int | ~int64 | ~float64
        }
        ```

        The `|` is a union, and the `~` means "any type whose underlying type \
        is this", so `type Celsius float64` satisfies `~float64`. Without the \
        tilde your own named types are excluded, which is almost never what you \
        meant.

        The standard library ships the common ones in `cmp` and `constraints`: \
        `cmp.Ordered` is everything `<` works on. Reaching for those before \
        writing your own is the usual advice, because a constraint is part of \
        your API and a homemade one is a second vocabulary for readers to learn.
        """,
        conceptTags: [GoConcept.constraint],
        task: .compile(
            starter: """
            package main

            // Sum should add up a slice of any numeric type and return the same
            // type it was given. Define whatever constraint it needs.

            func main() {
            \tprintln(Sum([]int{1, 2, 3}))
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            type Celsius float64

            func TestSumInts(t *testing.T) {
            \tif got := Sum([]int{1, 2, 3, 4}); got != 10 {
            \t\tt.Errorf("Sum ints = %d, want 10", got)
            \t}
            }

            func TestSumFloats(t *testing.T) {
            \tif got := Sum([]float64{1.5, 2.5}); got != 4 {
            \t\tt.Errorf("Sum floats = %v, want 4", got)
            \t}
            }

            // A named type with a numeric underlying type. This is what the
            // tilde is for; without it this does not compile.
            func TestSumNamedType(t *testing.T) {
            \tif got := Sum([]Celsius{10, 12}); got != 22 {
            \t\tt.Errorf("Sum named = %v, want 22", got)
            \t}
            }

            func TestSumEmptyIsZero(t *testing.T) {
            \tif got := Sum([]int{}); got != 0 {
            \t\tt.Errorf("Sum of nothing = %d, want 0", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        // The tilde is what lets a named type through: Celsius has float64 as
        // its underlying type, and without ~ it would be rejected.
        type Number interface {
        \t~int | ~int64 | ~float32 | ~float64
        }

        func Sum[T Number](values []T) T {
        \tvar total T
        \tfor _, value := range values {
        \t\ttotal += value
        \t}
        \treturn total
        }
        """
    )

    static let genericContainers = Lesson(
        id: "generics.containers",
        title: "A type can take parameters too",
        objective: "Write a container that holds one type rather than any type.",
        explanation: """
        Types take parameters with the same syntax: `type Stack[T any] struct \
        { items []T }`. Methods on it repeat the parameter in the receiver — \
        `func (s *Stack[T]) Push(v T)` — but they cannot introduce new ones. A \
        method needing its own type parameter has to be a function instead, \
        which is why `Map` is a function in every Go library and a method in \
        none.

        The zero value still has to work. `var s Stack[int]` gives you a struct \
        whose slice is nil, and appending to a nil slice is fine, so the stack \
        is usable without a constructor — worth designing for rather than \
        stumbling into.

        Instantiation is explicit where inference has nothing to work from: \
        `Stack[int]{}` names the type, while `Push(1)` infers nothing because \
        `T` is already fixed by the receiver.
        """,
        conceptTags: [GoConcept.typeParameter],
        task: .compile(
            starter: """
            package main

            // A Stack that holds one element type. Push adds, Pop returns the
            // most recently added value and whether there was one. The zero
            // value must be usable without a constructor.

            func main() {
            \tvar s Stack[string]
            \ts.Push("go")
            \tvalue, ok := s.Pop()
            \tprintln(value, ok)
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestStackIsLastInFirstOut(t *testing.T) {
            \tvar s Stack[int]
            \ts.Push(1)
            \ts.Push(2)

            \tif value, ok := s.Pop(); !ok || value != 2 {
            \t\tt.Fatalf("first Pop = %d, %v; want 2, true", value, ok)
            \t}
            \tif value, ok := s.Pop(); !ok || value != 1 {
            \t\tt.Fatalf("second Pop = %d, %v; want 1, true", value, ok)
            \t}
            }

            func TestPoppingAnEmptyStackReportsIt(t *testing.T) {
            \tvar s Stack[string]
            \tvalue, ok := s.Pop()
            \tif ok {
            \t\tt.Errorf("Pop on an empty stack said ok, returning %q", value)
            \t}
            \tif value != "" {
            \t\tt.Errorf("Pop on an empty stack returned %q, want the zero value", value)
            \t}
            }

            func TestTheZeroValueIsUsable(t *testing.T) {
            \tvar s Stack[int]
            \ts.Push(7)
            \tif value, ok := s.Pop(); !ok || value != 7 {
            \t\tt.Errorf("a stack used without a constructor lost its value")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        type Stack[T any] struct {
        \titems []T
        }

        func (s *Stack[T]) Push(value T) {
        \t// A nil slice appends fine, which is what makes the zero value work.
        \ts.items = append(s.items, value)
        }

        func (s *Stack[T]) Pop() (T, bool) {
        \tif len(s.items) == 0 {
        \t\t// The zero value of T, whatever T turned out to be.
        \t\tvar zero T
        \t\treturn zero, false
        \t}
        \tlast := len(s.items) - 1
        \tvalue := s.items[last]
        \ts.items = s.items[:last]
        \treturn value, true
        }
        """
    )

    static let whenNotToUseThem = Lesson(
        id: "generics.when-not-to",
        title: "Most code that could be generic should not be",
        objective: "Recognise the three cases where a type parameter earns its place, and the ones where it does not.",
        explanation: """
        The Go team's own guidance is narrow. Type parameters are for: \
        functions over slices, maps and channels of any element type; general \
        data structures like trees and stacks; and methods that are identical \
        for several types apart from the type itself.

        The case against everything else is readability. A generic function has \
        to be read twice — once for what it does and once for what its \
        constraint permits — and it cannot use anything the constraint does not \
        promise, which usually makes it *less* capable than the concrete \
        version it replaced.

        Two smells worth naming. If the constraint ends up being an interface \
        with methods and nothing else, an ordinary interface parameter is \
        simpler and does the same thing at the cost of one dynamic dispatch. \
        And if a function has a type parameter used exactly once, in one \
        argument, it is a plain function wearing a costume.
        """,
        conceptTags: [GoConcept.genericsOveruse],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Stringer interface {
            \tString() string
            }

            // Two ways to write the same thing.
            func PrintGeneric[T Stringer](value T) { fmt.Println(value.String()) }
            func PrintPlain(value Stringer)        { fmt.Println(value.String()) }

            type ID int

            func (i ID) String() string { return fmt.Sprintf("id-%d", i) }

            func main() {
            \tPrintGeneric(ID(7))
            \tPrintPlain(ID(7))
            }
            """,
            question: "Both compile and print the same thing. Which should you write, and why?",
            answer: """
            Both print id-7. Write PrintPlain.

            The constraint here is an interface with a method and nothing else,
            so the type parameter buys nothing: there is no second type
            involved, no container to keep typed, and no operator that needs a
            concrete type. What it costs is a signature that has to be read
            twice.

            The generic version does avoid one dynamic dispatch and one
            allocation of an interface value, which is a real difference — and
            an irrelevant one until a profiler says otherwise.
            """
        ),
        idiomaticSolution: nil
    )
}
