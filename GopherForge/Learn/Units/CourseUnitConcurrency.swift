import Foundation

/// Unit F — goroutines, channels, select and cancellation.
///
/// Every lesson here has a matching Concurrency Lab scenario, so a learner can
/// move from reading about a shape to watching a real program produce it.
enum CourseUnitConcurrency {
    static let unit = CourseUnit(
        id: "concurrency",
        title: "Concurrency",
        summary: "Goroutines, channel ownership, select and context, with the lab attached.",
        translationNote: """
        A goroutine is not a promise and not a thread. It has no handle, no \
        return value and no join — which is why channels and WaitGroups exist, \
        and why "who closes this channel" is a design question rather than a \
        detail.
        """,
        lessons: [goroutinesHaveNoHandle, senderOwnsClose, selectAndContext]
    )

    static let goroutinesHaveNoHandle = Lesson(
        id: "concurrency.no-handle",
        title: "go returns nothing",
        objective: "Get a result out of a goroutine, and know when the program stops waiting.",
        explanation: """
        go f() starts f and immediately continues. There is no future to await \
        and no value to collect, so the result has to come back through a \
        channel or a shared variable protected by something.

        The second half matters just as much: when main returns, the program \
        exits and every remaining goroutine simply stops. A goroutine still \
        blocked at that moment did not fail — it was never finished.
        """,
        conceptTags: [GoConcept.goroutineLeak, GoConcept.waitGroup],
        task: .predict(
            source: """
            package main

            import "fmt"

            func main() {
            \tresults := make(chan int)
            \tgo func() { results <- 42 }()
            \tgo func() { fmt.Println("this may never print") }()
            \tfmt.Println(<-results)
            }
            """,
            question: "Is the second goroutine guaranteed to print?",
            answer: """
            No.

            main returns as soon as it receives from results, and nothing makes \
            it wait for the second goroutine. It may print, may not, and the \
            program is wrong either way if the output matters.
            """
        ),
        idiomaticSolution: nil
    )

    static let senderOwnsClose = Lesson(
        id: "concurrency.channel-close",
        title: "The sender closes, the receiver ranges",
        objective: "Decide who closes a channel, and why the other side must not.",
        explanation: """
        Closing says "no more values will be sent". Only the goroutine that \
        sends can know that, which is why closing belongs to the sender — and \
        why a receiver that closes races with every send still in flight.

        Once ownership is right, receivers get two conveniences: range over a \
        channel ends when it closes, and v, ok := <-ch reports the difference \
        between a zero value and a closed channel.
        """,
        conceptTags: [GoConcept.channelClose],
        task: .compile(
            starter: """
            package main

            // squares should send each square and then let the consumer's range
            // loop finish on its own.
            func squares(n int) <-chan int {
            \tout := make(chan int)
            \tgo func() {
            \t\tfor i := 1; i <= n; i++ {
            \t\t\tout <- i * i
            \t\t}
            \t}()
            \treturn out
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestSquaresClosesWhenDone(t *testing.T) {
            \tvar got []int
            \tfor value := range squares(3) {
            \t\tgot = append(got, value)
            \t}
            \tif len(got) != 3 || got[0] != 1 || got[2] != 9 {
            \t\tt.Fatalf("squares produced %v", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let selectAndContext = Lesson(
        id: "concurrency.select-context",
        title: "select waits on several things; context says stop",
        objective: "Make a blocking operation cancellable without a flag or a kill switch.",
        explanation: """
        select blocks until one of its cases can proceed, and picks randomly \
        among those that are ready. Adding a case for <-ctx.Done() turns any \
        wait into a cancellable one.

        The convention that makes this composable: context is the first \
        parameter, it is passed rather than stored, and cancel is always \
        deferred so the resources behind it are released on every path.
        """,
        conceptTags: [GoConcept.selectBranch, GoConcept.contextCancel, GoConcept.contextFirstParameter],
        task: .compile(
            starter: """
            package main

            import (
            \t"context"
            \t"errors"
            )

            // waitFor should return ctx.Err() when the context is cancelled
            // before a value arrives.
            func waitFor(values <-chan int, ctx context.Context) (int, error) {
            \treturn <-values, nil
            }

            func main() { _ = errors.New }
            """,
            hiddenTest: """
            package main

            import (
            \t"context"
            \t"errors"
            \t"testing"
            )

            func TestWaitForCancelled(t *testing.T) {
            \tctx, cancel := context.WithCancel(context.Background())
            \tcancel()
            \t_, err := waitFor(make(chan int), ctx)
            \tif !errors.Is(err, context.Canceled) {
            \t\tt.Fatalf("err = %v, want context.Canceled", err)
            \t}
            }

            func TestWaitForValue(t *testing.T) {
            \tvalues := make(chan int, 1)
            \tvalues <- 7
            \tgot, err := waitFor(values, context.Background())
            \tif err != nil || got != 7 {
            \t\tt.Fatalf("waitFor = %d, %v", got, err)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func waitFor(ctx context.Context, values <-chan int) (int, error) {
        \tselect {
        \tcase value := <-values:
        \t\treturn value, nil
        \tcase <-ctx.Done():
        \t\treturn 0, ctx.Err()
        \t}
        }
        """
    )
}
