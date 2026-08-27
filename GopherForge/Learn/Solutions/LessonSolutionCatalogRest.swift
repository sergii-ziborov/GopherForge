import Foundation

/// The rest of the verified answers: interfaces, errors, modules, concurrency
/// and the standard library.
extension LessonSolutionCatalog {
    static let rest: [String: String] = [
        "interfaces.implicit": """
        package main

        type sized interface {
        \tLen() int
        }

        func summarise(s sized) int {
        \treturn s.Len()
        }

        func main() {}
        """,

        "interfaces.type-switch": """
        package main

        import "fmt"

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

        func main() { fmt.Println(Describe(7)) }
        """,

        "errors.wrapping": """
        package main

        import (
        \t"errors"
        \t"fmt"
        \t"strconv"
        )

        var ErrNotANumber = errors.New("not a number")

        func parsePort(raw string) (int, error) {
        \tn, err := strconv.Atoi(raw)
        \tif err != nil {
        \t\treturn 0, fmt.Errorf("parse port %q: %w", raw, ErrNotANumber)
        \t}
        \treturn n, nil
        }

        func main() {}
        """,

        "errors.custom-type": """
        package main

        import "fmt"

        type ParseError struct {
        \tField  string
        \tReason string
        }

        func (e *ParseError) Error() string {
        \treturn fmt.Sprintf("field %q: %s", e.Field, e.Reason)
        }

        func Parse(field, value string) error {
        \tif field == "" {
        \t\treturn &ParseError{Field: field, Reason: "name is empty"}
        \t}
        \treturn nil
        }

        func main() {}
        """,

        "modules.tests": """
        package main

        func Clamp(value, low, high int) int {
        \tif value < low {
        \t\treturn low
        \t}
        \tif value > high {
        \t\treturn high
        \t}
        \treturn value
        }

        func main() {}
        """,

        "concurrency.channel-close": """
        package main

        func squares(n int) <-chan int {
        \tout := make(chan int)
        \tgo func() {
        \t\tdefer close(out)
        \t\tfor i := 1; i <= n; i++ {
        \t\t\tout <- i * i
        \t\t}
        \t}()
        \treturn out
        }

        func main() {}
        """,

        "concurrency.select-context": """
        package main

        import "context"

        func waitFor(ctx context.Context, values <-chan int) (int, error) {
        \tselect {
        \tcase value := <-values:
        \t\treturn value, nil
        \tcase <-ctx.Done():
        \t\treturn 0, ctx.Err()
        \t}
        }

        func main() {}
        """,

        "concurrency.mutex": """
        package main

        import "sync"

        type Counter struct {
        \tmu    sync.Mutex
        \tcount map[string]int
        }

        func NewCounter() *Counter {
        \treturn &Counter{count: map[string]int{}}
        }

        func (c *Counter) Add(key string) {
        \tc.mu.Lock()
        \tdefer c.mu.Unlock()
        \tc.count[key]++
        }

        func (c *Counter) Get(key string) int {
        \tc.mu.Lock()
        \tdefer c.mu.Unlock()
        \treturn c.count[key]
        }

        func main() {}
        """,

        "concurrency.worker-pool": """
        package main

        import "sync"

        func Squares(numbers []int, workers int) []int {
        \tin, out := make(chan int), make(chan int)

        \tvar wg sync.WaitGroup
        \tfor range workers {
        \t\twg.Add(1)
        \t\tgo func() {
        \t\t\tdefer wg.Done()
        \t\t\tfor n := range in {
        \t\t\t\tout <- n * n
        \t\t\t}
        \t\t}()
        \t}

        \tgo func() {
        \t\tdefer close(in)
        \t\tfor _, n := range numbers {
        \t\t\tin <- n
        \t\t}
        \t}()

        \tgo func() {
        \t\twg.Wait()
        \t\tclose(out)
        \t}()

        \tresults := make([]int, 0, len(numbers))
        \tfor r := range out {
        \t\tresults = append(results, r)
        \t}
        \treturn results
        }

        func main() {}
        """,

        "stdlib.io": """
        package main

        import (
        \t"fmt"
        \t"io"
        \t"strings"
        )

        func WriteUpper(dst io.Writer, src io.Reader) error {
        \tdata, err := io.ReadAll(src)
        \tif err != nil {
        \t\treturn fmt.Errorf("read: %w", err)
        \t}
        \tif _, err := io.WriteString(dst, strings.ToUpper(string(data))); err != nil {
        \t\treturn fmt.Errorf("write: %w", err)
        \t}
        \treturn nil
        }

        func main() {}
        """,

        "stdlib.sort": """
        package main

        import (
        \t"cmp"
        \t"slices"
        )

        type Release struct {
        \tName string
        \tYear int
        }

        func SortReleases(releases []Release) {
        \tslices.SortFunc(releases, func(a, b Release) int {
        \t\tif c := cmp.Compare(a.Year, b.Year); c != 0 {
        \t\t\treturn c
        \t\t}
        \t\treturn cmp.Compare(a.Name, b.Name)
        \t})
        }

        func main() {}
        """,

        "stdlib.context": """
        package main

        import (
        \t"context"
        \t"time"
        )

        func WaitFor(ctx context.Context, d time.Duration) error {
        \ttimer := time.NewTimer(d)
        \tdefer timer.Stop()

        \tselect {
        \tcase <-timer.C:
        \t\treturn nil
        \tcase <-ctx.Done():
        \t\treturn ctx.Err()
        \t}
        }

        func main() {}
        """,
    ]
}
