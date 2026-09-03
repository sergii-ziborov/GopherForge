import Foundation

/// Types you define: structs, methods, pointers and functions as values.
///
/// The gap this unit fills was embarrassing. The course taught `:=`, switch and
/// conversions, and never once showed how to declare a type of your own — which
/// is most of what writing Go consists of.
enum CourseUnitStructs {
    static let unit = CourseUnit(
        id: "structs",
        title: "Types you define",
        summary: "Structs, methods, pointers, and functions that are values.",
        translationNote: """
        There is no class here and nothing to inherit from. A struct is data, \
        a method is a function with a receiver written before its name, and \
        the two are declared separately — which means you can put methods on \
        any type you define, not only on structs.

        The habit to unlearn is reaching for a pointer by default. In Go a \
        value is copied unless you say otherwise, and that is usually what you \
        want; a pointer is for when the method has to change the thing it was \
        called on, or when copying it would genuinely cost.
        """,
        lessons: [
            structLiterals,
            methodsAndReceivers,
            pointersWhenTheyAreNeeded,
            closuresCaptureVariables,
            whatEscapes,
        ]
    )

    static let structLiterals = Lesson(
        id: "structs.literals",
        title: "A struct is data, and its fields have names",
        objective: "Declare a struct type and build values of it without positional guessing.",
        explanation: """
        A struct groups fields under a type name. Building one has two forms, \
        and only one of them is safe to read: `Point{X: 1, Y: 2}` names its \
        fields, and `Point{1, 2}` relies on declaration order. The second \
        breaks silently the day somebody adds a field in the middle, which is \
        why the named form is what you will see in real code and what vet \
        prefers for structs from other packages.

        A struct you do not initialise is not nil — it is its zero value, with \
        every field at its own zero. `var p Point` is usable immediately, and \
        `p.X` is 0 rather than a crash.

        Fields whose names begin with a capital are visible outside the \
        package; the rest are not. That is the same rule as for functions, and \
        it is decided per field rather than per struct.
        """,
        conceptTags: [GoConcept.structLiteral],
        task: .compile(
            starter: """
            package main

            // Declare a Rect type with Width and Height fields of type int,
            // then finish Area so it returns their product.

            func Area(r Rect) int {
            \treturn 0
            }

            func main() {
            \tprintln(Area(Rect{Width: 3, Height: 4}))
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestArea(t *testing.T) {
            \tcases := []struct {
            \t\tname string
            \t\tin   Rect
            \t\twant int
            \t}{
            \t\t{name: "three by four", in: Rect{Width: 3, Height: 4}, want: 12},
            \t\t{name: "zero value", in: Rect{}, want: 0},
            \t\t{name: "one side", in: Rect{Width: 5}, want: 0},
            \t}
            \tfor _, testCase := range cases {
            \t\tt.Run(testCase.name, func(t *testing.T) {
            \t\t\tif got := Area(testCase.in); got != testCase.want {
            \t\t\t\tt.Errorf("Area(%+v) = %d, want %d", testCase.in, got, testCase.want)
            \t\t\t}
            \t\t})
            \t}
            }
            """
        ),
        idiomaticSolution: """
        type Rect struct {
        \tWidth  int
        \tHeight int
        }

        func Area(r Rect) int {
        \treturn r.Width * r.Height
        }
        """
    )

    static let methodsAndReceivers = Lesson(
        id: "structs.methods",
        title: "A method is a function with a receiver",
        objective: "Put a method on your own type and choose the receiver deliberately.",
        explanation: """
        A method is declared outside the type, with the receiver in \
        parentheses before the name: `func (r Rect) Area() int`. There is no \
        class body, and methods can be attached to any type you declared in \
        this package — including `type Celsius float64`, not only structs.

        The receiver is a copy unless it is a pointer. `func (r Rect) Grow()` \
        mutates a copy and the caller sees nothing; `func (r *Rect) Grow()` \
        mutates the original. Go calls either form for you — `r.Grow()` works \
        on an addressable value whichever receiver you chose — so the compiler \
        will not warn you that the mutation went nowhere.

        The convention is to pick one kind of receiver for the whole type. A \
        type with some value methods and some pointer methods has a method set \
        that changes depending on whether you hold a value or a pointer, and \
        that is where "it does not satisfy the interface" comes from.
        """,
        conceptTags: [GoConcept.pointerReceiver, GoConcept.methodSet],
        task: .compile(
            starter: """
            package main

            type Counter struct {
            \tTotal int
            }

            // Add should increase the counter by n, and the change must be
            // visible to the caller. Total should report the current value.

            func main() {
            \tc := Counter{}
            \tc.Add(3)
            \tprintln(c.Value())
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestAddIsVisibleToTheCaller(t *testing.T) {
            \tc := Counter{}
            \tc.Add(3)
            \tc.Add(4)
            \tif got := c.Value(); got != 7 {
            \t\tt.Errorf("after adding 3 and 4, Value() = %d, want 7", got)
            \t}
            }

            func TestZeroValueIsUsable(t *testing.T) {
            \tvar c Counter
            \tif got := c.Value(); got != 0 {
            \t\tt.Errorf("a fresh Counter reports %d, want 0", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        // A pointer receiver, because the method changes the receiver and the
        // caller has to see it.
        func (c *Counter) Add(n int) {
        \tc.Total += n
        }

        // A pointer receiver here too, not because it mutates but because a
        // type is easier to reason about when all its methods agree.
        func (c *Counter) Value() int {
        \treturn c.Total
        }
        """
    )

    static let pointersWhenTheyAreNeeded = Lesson(
        id: "structs.pointers",
        title: "A pointer is for changing something, not for speed",
        objective: "Say when a pointer is required and when it is only noise.",
        explanation: """
        Go passes everything by value. A struct handed to a function is copied, \
        and writing to the copy changes nothing the caller can see. A pointer \
        is how you say "the same one", and `&` and `*` are the whole syntax: \
        `&value` takes an address, `*pointer` reads through one. Field access \
        needs no `*` — `p.X` works on a pointer as well as a value, which is \
        why you rarely see the star in ordinary code.

        There is no pointer arithmetic. A Go pointer either points at something \
        or is nil, and that is all it can do — which is why passing one is safe \
        in a way it is not in C.

        The reason to use one is mutation. "Pointers are faster" is a guess: \
        for a small struct the copy is often cheaper than the indirection and \
        the extra work the garbage collector inherits. Measure before believing \
        it, and until you have, choose based on whether the callee needs to \
        change what it was given.
        """,
        conceptTags: [GoConcept.pointerReceiver],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Settings struct {
            \tRetries int
            }

            func byValue(s Settings) {
            \ts.Retries = 9
            }

            func byPointer(s *Settings) {
            \ts.Retries = 9
            }

            func main() {
            \ts := Settings{Retries: 1}
            \tbyValue(s)
            \tfmt.Println(s.Retries)
            \tbyPointer(&s)
            \tfmt.Println(s.Retries)
            }
            """,
            question: "What are the two numbers, and why are they different?",
            answer: """
            1, then 9.

            byValue was handed a copy of the struct. It set Retries on the copy,
            the copy went out of scope, and the caller's value never changed —
            the compiler says nothing, because assigning to your own parameter
            is perfectly legal.

            byPointer was handed the address, so `s.Retries = 9` wrote through
            to the original. Note that neither function needed a `*` to reach
            the field: Go dereferences for you on field access.
            """
        ),
        idiomaticSolution: nil
    )

    static let closuresCaptureVariables = Lesson(
        id: "structs.closures",
        title: "A function is a value, and it remembers where it came from",
        objective: "Return a function that carries state, and know what it captured.",
        explanation: """
        Functions are values in Go: they can be stored, passed and returned. A \
        function literal declared inside another function keeps a reference to \
        the variables it used — not a copy of them. That is a closure, and it \
        is how `sort.Slice` takes a comparison and how a middleware wraps a \
        handler.

        Captured by reference matters. Two closures over the same variable see \
        each other's writes, which is either exactly what you wanted or a bug \
        you will spend an afternoon on. When you want independence, give each \
        closure its own variable.

        The loop-variable trap that used to live here is gone: since Go 1.22 \
        each iteration gets a fresh variable, so a closure made in a loop \
        captures that iteration's value. Code written before 1.22 works around \
        it with an extra assignment, which is why you will still see it.
        """,
        conceptTags: [GoConcept.closure],
        task: .compile(
            starter: """
            package main

            // Counter should return a function that returns 1 the first time it
            // is called, 2 the second time, and so on. Two counters made by two
            // calls must not share their count.

            func main() {
            \tnext := Counter()
            \tprintln(next(), next())
            }
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestCounterCountsUp(t *testing.T) {
            \tnext := Counter()
            \tfor want := 1; want <= 3; want++ {
            \t\tif got := next(); got != want {
            \t\t\tt.Fatalf("call %d returned %d", want, got)
            \t\t}
            \t}
            }

            func TestTwoCountersAreIndependent(t *testing.T) {
            \tfirst := Counter()
            \tsecond := Counter()
            \tfirst()
            \tfirst()
            \tif got := second(); got != 1 {
            \t\tt.Errorf("a fresh counter returned %d, want 1; the two share state", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Counter() func() int {
        \t// Declared inside Counter, so every call to Counter gets its own.
        \tcount := 0
        \treturn func() int {
        \t\tcount++
        \t\treturn count
        \t}
        }
        """
    )

    static let whatEscapes = Lesson(
        id: "structs.escape",
        title: "Returning a pointer to a local is fine",
        objective: "Explain why Go lets you return the address of a local variable.",
        explanation: """
        In C this is the classic mistake: return the address of a local and the \
        stack frame is gone by the time the caller looks. Go removes the \
        mistake rather than warning about it. The compiler works out that the \
        value outlives the function — escape analysis — and allocates it \
        somewhere that survives.

        So `return &Config{}` is ordinary, idiomatic Go, and constructors \
        called `New...` do it constantly. You are not choosing stack or heap; \
        the compiler is, from how the value is used.

        What this does *not* mean is that pointers are free. An escaping value \
        becomes garbage collector work, which is the real cost behind "pointers \
        are faster" being a guess rather than a rule.
        """,
        conceptTags: [GoConcept.pointerReceiver],
        task: .predict(
            source: """
            package main

            import "fmt"

            type Config struct {
            \tName string
            }

            func New(name string) *Config {
            \tlocal := Config{Name: name}
            \treturn &local
            }

            func main() {
            \tfirst := New("a")
            \tsecond := New("b")
            \tfmt.Println(first.Name, second.Name, first == second)
            }
            """,
            question: "Does this compile, and what does it print?",
            answer: """
            It compiles, and prints: a b false

            `local` escapes, so the compiler allocates it where it can outlive
            the call. Every call to New produces a distinct value, so the two
            pointers are different and `first == second` is false — pointer
            comparison asks whether they point at the same thing, not whether
            the things are equal.
            """
        ),
        idiomaticSolution: nil
    )
}
