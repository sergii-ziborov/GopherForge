import Foundation

/// Answers for the two units added last: the types you declare yourself, and
/// generics.
///
/// Kept in their own file for the same reason the others are split — these are
/// whole programs, and a single catalogue would be a thousand lines of string
/// literal that nobody can find anything in.
extension LessonSolutionCatalog {
    static let typesAndGenerics: [String: String] = [
        "collections.iterators": """
        package main

        func Take(values []string, n int) func(func(string) bool) {
        \treturn func(yield func(string) bool) {
        \t\tfor i, value := range values {
        \t\t\tif i >= n {
        \t\t\t\treturn
        \t\t\t}
        \t\t\tif !yield(value) {
        \t\t\t\treturn
        \t\t\t}
        \t\t}
        \t}
        }

        func main() {
        \tfor value := range Take([]string{"go", "forge", "run"}, 2) {
        \t\tprintln(value)
        \t}
        }
        """,

        "generics.methods": """
        package main

        type Bag[E any] struct {
        \titems []E
        }

        func (b Bag[E]) Map[F any](f func(E) F) Bag[F] {
        \tmapped := make([]F, 0, len(b.items))
        \tfor _, item := range b.items {
        \t\tmapped = append(mapped, f(item))
        \t}
        \treturn Bag[F]{items: mapped}
        }

        func main() {
        \tb := Bag[int]{items: []int{1, 2, 3}}
        \tprintln(len(b.Map(func(n int) string { return "x" }).items))
        }
        """,

        "structs.literals": """
        package main

        type Rect struct {
        \tWidth  int
        \tHeight int
        }

        func Area(r Rect) int {
        \treturn r.Width * r.Height
        }

        func main() {
        \tprintln(Area(Rect{Width: 3, Height: 4}))
        }
        """,

        "structs.methods": """
        package main

        type Counter struct {
        \tTotal int
        }

        // A pointer receiver, because the method changes the receiver and the
        // caller has to see it.
        func (c *Counter) Add(n int) {
        \tc.Total += n
        }

        func (c *Counter) Value() int {
        \treturn c.Total
        }

        func main() {
        \tc := Counter{}
        \tc.Add(3)
        \tprintln(c.Value())
        }
        """,

        "structs.closures": """
        package main

        func Counter() func() int {
        \t// Declared inside Counter, so every call to Counter gets its own.
        \tcount := 0
        \treturn func() int {
        \t\tcount++
        \t\treturn count
        \t}
        }

        func main() {
        \tnext := Counter()
        \tprintln(next(), next())
        }
        """,

        "generics.type-parameters": """
        package main

        func Keep[T any](in []T, keep func(T) bool) []T {
        \tvar out []T
        \tfor _, value := range in {
        \t\tif keep(value) {
        \t\t\tout = append(out, value)
        \t\t}
        \t}
        \treturn out
        }

        func main() {
        \teven := Keep([]int{1, 2, 3, 4}, func(n int) bool { return n%2 == 0 })
        \tprintln(len(even))
        }
        """,

        "generics.constraints": """
        package main

        // The tilde is what lets a named type through: a type whose underlying
        // type is float64 satisfies ~float64, and without it the constraint
        // would accept only float64 itself.
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

        func main() {
        \tprintln(Sum([]int{1, 2, 3}))
        }
        """,

        "generics.containers": """
        package main

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

        func main() {
        \tvar s Stack[string]
        \ts.Push("go")
        \tvalue, ok := s.Pop()
        \tprintln(value, ok)
        }
        """,
    ]
}
