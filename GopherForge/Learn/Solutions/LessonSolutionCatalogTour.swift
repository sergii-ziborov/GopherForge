import Foundation

/// Verified answers for the Tour of Go lessons added after the first course.
extension LessonSolutionCatalog {
    static let tour: [String: String] = [
        "core.named-results": """
        package main

        func Split(n, d int) (quot, rem int) {
        \tquot = n / d
        \trem = n % d
        \treturn
        }

        func main() {}
        """,

        "collections.make-and-new": """
        package main

        func ReadyMap() map[string]int { return make(map[string]int) }
        func ZeroCounter() *int        { return new(int) }

        func main() {}
        """,

        "collections.arrays": """
        package main

        func FirstThree(values [4]int) [3]int {
        \treturn [3]int{values[0], values[1], values[2]}
        }

        func main() {}
        """,

        "collections.map-ok": """
        package main

        func Has(m map[string]int, key string) bool {
        \t_, ok := m[key]
        \treturn ok
        }

        func main() {}
        """,

        "interfaces.stringer": """
        package main

        import "fmt"

        type IPAddr [4]byte

        func (ip IPAddr) String() string {
        \treturn fmt.Sprintf("%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3])
        }

        func main() {}
        """,

        "interfaces.empty": """
        package main

        import "fmt"

        func Kind(value any) string {
        \treturn fmt.Sprintf("%T", value)
        }

        func main() {}
        """,

        "concurrency.buffered": """
        package main

        func Fill(n int) []int {
        \tch := make(chan int, n)
        \tfor i := 0; i < n; i++ {
        \t\tch <- i
        \t}
        \tclose(ch)
        \tout := make([]int, 0, n)
        \tfor v := range ch {
        \t\tout = append(out, v)
        \t}
        \treturn out
        }

        func main() {}
        """,

        "concurrency.range-and-close": """
        package main

        func Drain(ch <-chan int) []int {
        \tout := []int{}
        \tfor v := range ch {
        \t\tout = append(out, v)
        \t}
        \treturn out
        }

        func main() {}
        """,

        "concurrency.select-default": """
        package main

        func TryRecv(ch <-chan int) (int, bool) {
        \tselect {
        \tcase v := <-ch:
        \t\treturn v, true
        \tdefault:
        \t\treturn 0, false
        \t}
        }

        func main() {}
        """,

        "concurrency.direction": """
        package main

        func Produce(out chan<- int, values []int) {
        \tdefer close(out)
        \tfor _, v := range values {
        \t\tout <- v
        \t}
        }

        func main() {}
        """,

        "stdlib.http": """
        package main

        import (
        \t"io"
        \t"net/http"
        )

        func Hello() http.Handler {
        \treturn http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        \t\tif r.URL.Path != "/hello" {
        \t\t\thttp.NotFound(w, r)
        \t\t\treturn
        \t\t}
        \t\tio.WriteString(w, "hi")
        \t})
        }

        func main() {}
        """,

        "stdlib.strconv": """
        package main

        import (
        \t"fmt"
        \t"strconv"
        )

        func ParsePort(raw string) (int, error) {
        \tn, err := strconv.Atoi(raw)
        \tif err != nil {
        \t\treturn 0, err
        \t}
        \tif n < 1 || n > 65535 {
        \t\treturn 0, fmt.Errorf("port %d out of range", n)
        \t}
        \treturn n, nil
        }

        func main() {}
        """,

        "errors.recover": """
        package main

        import "fmt"

        func Guard(work func()) (err error) {
        \tdefer func() {
        \t\tif r := recover(); r != nil {
        \t\t\terr = fmt.Errorf("panic: %v", r)
        \t\t}
        \t}()
        \twork()
        \treturn nil
        }

        func main() {}
        """,

        "concurrency.once": """
        package main

        import "sync"

        func Call(once *sync.Once, fn func()) {
        \tonce.Do(fn)
        }

        func main() {}
        """,

        "collections.function-values": """
        package main

        func Apply(values []int, fn func(int) int) []int {
        \tout := make([]int, len(values))
        \tfor i, v := range values {
        \t\tout[i] = fn(v)
        \t}
        \treturn out
        }

        func main() {}
        """,

        "stdlib.image": """
        package main

        import (
        \t"image"
        \t"image/color"
        )

        type Solid struct {
        \tW, H int
        \tC    color.RGBA
        }

        func (s Solid) ColorModel() color.Model { return color.RGBAModel }

        func (s Solid) Bounds() image.Rectangle {
        \treturn image.Rect(0, 0, s.W, s.H)
        }

        func (s Solid) At(x, y int) color.Color { return s.C }

        func main() {}
        """,
    ]
}
