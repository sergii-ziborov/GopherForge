import Foundation

/// Examples for goroutines, channels and context.
///
/// Every one of these is written so its output cannot depend on scheduling.
/// That is not a simplification for the sake of the test: an example whose
/// output changes between runs teaches that concurrency is unpredictable, when
/// the lesson worth teaching is how to make it predictable.
enum GoExampleLibraryConcurrency {
    static let all: [GoExample] = [waitGroup, unbufferedRendezvous, selectWithTimeout, contextCancel]

    static let waitGroup = GoExample(
        id: "conc.waitgroup",
        title: "Wait for every goroutine",
        summary: "Add before you start, Done inside, Wait once.",
        takeaway: "Results collected by index instead of by arrival order are deterministic.",
        conceptTags: [GoConcept.waitGroup],
        source: """
        package main

        import (
        \t"fmt"
        \t"sync"
        )

        func main() {
        \tinput := []int{1, 2, 3, 4, 5}
        \tsquares := make([]int, len(input))

        \tvar wg sync.WaitGroup
        \tfor i, n := range input {
        \t\twg.Add(1)
        \t\tgo func() {
        \t\t\tdefer wg.Done()
        \t\t\t// Writing to its own index needs no lock: no two goroutines
        \t\t\t// touch the same element.
        \t\t\tsquares[i] = n * n
        \t\t}()
        \t}
        \twg.Wait()

        \tfmt.Println(squares)
        }
        """,
        expectedOutput: "[1 4 9 16 25]\n"
    )

    static let unbufferedRendezvous = GoExample(
        id: "conc.rendezvous",
        title: "An unbuffered channel is a handshake",
        summary: "The send finishes only when a receiver takes the value.",
        takeaway: "Send before anyone is receiving and the whole program stops.",
        conceptTags: [GoConcept.deadlock, GoConcept.channelClose],
        source: """
        package main

        import "fmt"

        func main() {
        \tch := make(chan string)

        \tgo func() {
        \t\t// This send blocks until main reaches the receive below.
        \t\tch <- "handed over"
        \t\tclose(ch)
        \t}()

        \tfmt.Println(<-ch)

        \t// Receiving from a closed channel returns the zero value at once.
        \tvalue, open := <-ch
        \tfmt.Printf("after close: %q open=%v\\n", value, open)
        }
        """,
        expectedOutput: """
        handed over
        after close: "" open=false

        """
    )

    static let selectWithTimeout = GoExample(
        id: "conc.select",
        title: "select takes whichever is ready",
        summary: "A timeout is just another channel in the same select.",
        takeaway: "With a default, select never blocks; without one, it waits for a branch.",
        conceptTags: [GoConcept.selectBranch],
        source: """
        package main

        import (
        \t"fmt"
        \t"time"
        )

        func main() {
        \tslow := make(chan string)
        \tgo func() {
        \t\ttime.Sleep(50 * time.Millisecond)
        \t\tslow <- "arrived"
        \t}()

        \t// Nothing is ready yet, and default means "do not wait".
        \tselect {
        \tcase value := <-slow:
        \t\tfmt.Println("immediate:", value)
        \tdefault:
        \t\tfmt.Println("immediate: nothing ready")
        \t}

        \t// No default, so this one waits for whichever branch fires first.
        \tselect {
        \tcase value := <-slow:
        \t\tfmt.Println("waited:", value)
        \tcase <-time.After(2 * time.Second):
        \t\tfmt.Println("waited: timed out")
        \t}
        }
        """,
        expectedOutput: """
        immediate: nothing ready
        waited: arrived

        """
    )

    static let contextCancel = GoExample(
        id: "context.cancel",
        title: "Context stops work you no longer need",
        summary: "A cancelled context tells every goroutine holding it to stop.",
        takeaway: "ctx is the first parameter, and its Done channel is what you select on.",
        conceptTags: [GoConcept.contextCancel, GoConcept.contextFirstParameter],
        source: """
        package main

        import (
        \t"context"
        \t"fmt"
        \t"time"
        )

        func work(ctx context.Context, done chan<- string) {
        \tselect {
        \tcase <-time.After(2 * time.Second):
        \t\tdone <- "finished the long job"
        \tcase <-ctx.Done():
        \t\tdone <- "stopped: " + ctx.Err().Error()
        \t}
        }

        func main() {
        \tctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
        \tdefer cancel()

        \tdone := make(chan string)
        \tgo work(ctx, done)

        \tfmt.Println(<-done)
        }
        """,
        expectedOutput: "stopped: context deadline exceeded\n"
    )
}
