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
}
