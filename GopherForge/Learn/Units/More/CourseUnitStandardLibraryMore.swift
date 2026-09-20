import Foundation

/// Three more for the standard library: time, sorting, and context in practice.
extension CourseUnitStandardLibrary {
    static let timeAndDuration = Lesson(
        id: "stdlib.time",
        title: "A Duration is a number of nanoseconds with a type",
        objective: "Write a timeout without wondering what unit it is in.",
        explanation: """
        `time.Duration` is an int64 counting nanoseconds, and the constants are \
        what make it readable: `5 * time.Second` is a multiplication, not a \
        function call. That is also the trap — a bare `5` is five nanoseconds, \
        and `time.Sleep(5)` returns immediately rather than after five of \
        anything.

        Two more worth knowing on sight: subtracting two Times gives a \
        Duration, and comparing Times uses Before, After and Equal rather than \
        the operators, because a Time carries a monotonic reading as well as a \
        wall clock.
        """,
        conceptTags: [GoConcept.stdlibTime],
        task: .predict(
            source: """
            package main

            import (
            \t"fmt"
            \t"time"
            )

            func main() {
            \td := 90 * time.Second
            \tfmt.Println(d)
            \tfmt.Println(d.Minutes())

            \tstart := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
            \tend := start.Add(36 * time.Hour)
            \tfmt.Println(end.Sub(start))
            \tfmt.Println(end.After(start))
            }
            """,
            question: "What does this print? Durations print themselves.",
            answer: """
            1m30s
            1.5
            36h0m0s
            true
            """
        ),
        idiomaticSolution: nil
    )

    static let sorting = Lesson(
        id: "stdlib.sort",
        title: "Sorting by whatever you like",
        objective: "Sort a slice of structs by two keys.",
        explanation: """
        `slices.SortFunc` takes a comparison that returns a negative number, \
        zero or a positive one — not a bool. That trips people coming from \
        languages where the comparator answers "is a before b". `cmp.Compare` \
        does the right thing for any ordered type and is what the comparison \
        should usually be built from.

        For a second key, compare the first and fall through only when it is \
        equal. That is the whole pattern, and it is worth writing out once.
        """,
        conceptTags: [GoConcept.stdlibSort],
        task: .compile(
            starter: """
            package main

            type Release struct {
            \tName string
            \tYear int
            }

            // SortReleases orders by year ascending, and by name for
            // releases from the same year. It sorts in place.
            func SortReleases(releases []Release) {}

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestSortReleases(t *testing.T) {
            \treleases := []Release{
            \t\t{"zeta", 2020},
            \t\t{"alpha", 2020},
            \t\t{"beta", 2018},
            \t}
            \tSortReleases(releases)

            \twant := []Release{{"beta", 2018}, {"alpha", 2020}, {"zeta", 2020}}
            \tfor i := range want {
            \t\tif releases[i] != want[i] {
            \t\t\tt.Fatalf("got %v, want %v", releases, want)
            \t\t}
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func SortReleases(releases []Release) {
        \tslices.SortFunc(releases, func(a, b Release) int {
        \t\tif c := cmp.Compare(a.Year, b.Year); c != 0 {
        \t\t\treturn c
        \t\t}
        \t\treturn cmp.Compare(a.Name, b.Name)
        \t})
        }
        """
    )

    static let contextInPractice = Lesson(
        id: "stdlib.context",
        title: "Every blocking call should take a context",
        objective: "Make a function that waits stop waiting when told to.",
        explanation: """
        A context is how a caller says "stop, I no longer need this". Anything \
        that could block — a network call, a sleep, a channel receive — should \
        take one and should select on `ctx.Done()` alongside whatever it was \
        waiting for. A function that ignores its context is a function nothing \
        can cancel.

        `ctx.Err()` says which happened: `context.Canceled` when someone called \
        cancel, `context.DeadlineExceeded` when the timeout ran out. Returning \
        it directly is usually right — the caller already knows what it asked \
        for.
        """,
        conceptTags: [GoConcept.contextCancel, GoConcept.contextFirstParameter],
        task: .compile(
            starter: """
            package main

            import (
            \t"context"
            \t"time"
            )

            // WaitFor returns nil once d has passed, or the context's error
            // if the context finishes first. It must not outlive either.
            func WaitFor(ctx context.Context, d time.Duration) error {
            \ttime.Sleep(d)
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"context"
            \t"errors"
            \t"testing"
            \t"time"
            )

            func TestWaitForRespectsTheContext(t *testing.T) {
            \tif err := WaitFor(context.Background(), time.Millisecond); err != nil {
            \t\tt.Errorf("a short wait should succeed, got %v", err)
            \t}

            \tctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
            \tdefer cancel()

            \tstart := time.Now()
            \terr := WaitFor(ctx, 5*time.Second)
            \tif !errors.Is(err, context.DeadlineExceeded) {
            \t\tt.Fatalf("err = %v, want DeadlineExceeded", err)
            \t}
            \tif time.Since(start) > time.Second {
            \t\tt.Error("WaitFor kept waiting after the context finished")
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let httpHandler = Lesson(
        id: "stdlib.http",
        title: "http.Handler is one method, like Reader",
        objective: "Serve /hello from an in-memory request, with no listen.",
        explanation: """
        Go's own "Writing Web Applications" tutorial and the Tour's "where \
        to go next" both land on `http.Handler`. It is one method:

            ServeHTTP(http.ResponseWriter, *http.Request)

        `http.HandlerFunc` turns a function into that type. `http.ServeMux` \
        is a Handler that dispatches to others. The sandbox has no network, \
        so this lesson uses `httptest`: the types are real, the listen is \
        not. A function that accepts `http.Handler` can be tested the same \
        way in any Go module.
        """,
        conceptTags: [GoConcept.stdlibHTTP, GoConcept.smallInterface],
        task: .compile(
            starter: """
            package main

            import "net/http"

            // Hello answers GET /hello with "hi" and 404 for anything else.
            func Hello() http.Handler {
            \treturn http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {})
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"io"
            \t"net/http"
            \t"net/http/httptest"
            \t"testing"
            )

            func TestHello(t *testing.T) {
            \th := Hello()
            \treq := httptest.NewRequest(http.MethodGet, "/hello", nil)
            \trec := httptest.NewRecorder()
            \th.ServeHTTP(rec, req)
            \tif rec.Code != 200 {
            \t\tt.Fatalf("status %d, want 200", rec.Code)
            \t}
            \tbody, _ := io.ReadAll(rec.Result().Body)
            \tif string(body) != "hi" {
            \t\tt.Fatalf("body %q, want hi", body)
            \t}

            \tmiss := httptest.NewRecorder()
            \th.ServeHTTP(miss, httptest.NewRequest(http.MethodGet, "/nope", nil))
            \tif miss.Code != 404 {
            \t\tt.Fatalf("missing path status %d, want 404", miss.Code)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Hello() http.Handler {
        \treturn http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        \t\tif r.URL.Path != "/hello" {
        \t\t\thttp.NotFound(w, r)
        \t\t\treturn
        \t\t}
        \t\tio.WriteString(w, "hi")
        \t})
        }
        """
    )

    static let strconvAtoi = Lesson(
        id: "stdlib.strconv",
        title: "strconv is how text becomes a number",
        objective: "Parse a port with Atoi and reject anything outside 1…65535.",
        explanation: """
        The Tour's Errors page uses `strconv.Atoi` as the example of a \
        function that returns `(int, error)`. That is the package: no \
        `ParseInt` surprises in everyday code, no `fmt.Sscan` for a single \
        number. `Atoi` is `ParseInt(s, 10, 0)` with a shorter name.

        Failure is an error, not a panic and not a zero you are meant to \
        guess at. Discarding that error is how `"x"` becomes port 0.
        """,
        conceptTags: [GoConcept.stdlibStrconv, GoConcept.explicitErrorCheck],
        task: .compile(
            starter: """
            package main

            // ParsePort accepts 1 through 65535. Anything else is an error,
            // including text that is not a number.
            func ParsePort(raw string) (int, error) {
            \treturn 0, nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestParsePort(t *testing.T) {
            \tn, err := ParsePort("8080")
            \tif err != nil || n != 8080 {
            \t\tt.Fatalf("8080 -> %d, %v", n, err)
            \t}
            \tif _, err := ParsePort("nope"); err == nil {
            \t\tt.Fatal("text must be an error")
            \t}
            \tif _, err := ParsePort("0"); err == nil {
            \t\tt.Fatal("0 is not a port")
            \t}
            \tif _, err := ParsePort("70000"); err == nil {
            \t\tt.Fatal("70000 is out of range")
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let imageInterface = Lesson(
        id: "stdlib.image",
        title: "image.Image is three methods, not a file",
        objective: "Implement a solid-colour image the standard library will accept.",
        explanation: """
        The Tour's "Images" page: `image.Image` is ColorModel, Bounds and \
        At. A PNG file implements it. So does a type you write in ten \
        lines. `image/draw` and `image/png` talk to the interface, not to \
        a concrete bitmap.

        This lesson is a solid rectangle: every pixel the same colour, \
        bounds you choose. The Tour exercise asks for a generated picture; \
        the interface is the same.
        """,
        conceptTags: [GoConcept.stdlibImage],
        task: .compile(
            starter: """
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
            func (s Solid) Bounds() image.Rectangle { return image.Rectangle{} }
            func (s Solid) At(x, y int) color.Color { return color.RGBA{} }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"image"
            \t"image/color"
            \t"testing"
            )

            func TestSolidIsAnImage(t *testing.T) {
            \tvar img image.Image = Solid{W: 4, H: 3, C: color.RGBA{1, 2, 3, 255}}
            \tb := img.Bounds()
            \tif b.Dx() != 4 || b.Dy() != 3 {
            \t\tt.Fatalf("bounds %v, want 4x3", b)
            \t}
            \tgot, ok := img.At(1, 1).(color.RGBA)
            \tif !ok || got != (color.RGBA{1, 2, 3, 255}) {
            \t\tt.Fatalf("At = %v", img.At(1, 1))
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func (s Solid) Bounds() image.Rectangle {
        \treturn image.Rect(0, 0, s.W, s.H)
        }
        func (s Solid) At(x, y int) color.Color { return s.C }
        """
    )
}
