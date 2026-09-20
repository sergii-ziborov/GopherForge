import Foundation

/// The Tour of Go concurrency pages this unit used to skip: buffers, ranging
/// until close, select's default, and the direction in the type.
extension CourseUnitConcurrency {
    static let bufferedChannels = Lesson(
        id: "concurrency.buffered",
        title: "A buffer is a mailbox, not a meeting",
        objective: "Send n values on a channel of capacity n without another goroutine.",
        explanation: """
        The Tour's "Buffered Channels" page: `make(chan int, 100)` sends \
        without a receiver until the buffer is full, and receives without a \
        sender until it is empty. An unbuffered channel is a rendezvous. A \
        buffered one is a mailbox of a known size.

        The deadlock people then write is filling a buffer of 1 with two \
        sends from the only goroutine there is. The buffer does not make \
        the channel unbounded. It makes the bound visible in the `make`.
        """,
        conceptTags: [GoConcept.bufferedChannel, GoConcept.deadlock],
        task: .compile(
            starter: """
            package main

            // Fill sends 0..n-1 on a channel of capacity n, closes it, and
            // returns what a range reads back. It must not start a goroutine.
            func Fill(n int) []int {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestFillDoesNotNeedAPartner(t *testing.T) {
            \tgot := Fill(4)
            \tif len(got) != 4 {
            \t\tt.Fatalf("got %v, want four values", got)
            \t}
            \tfor i, v := range got {
            \t\tif v != i {
            \t\t\tt.Fatalf("got %v", got)
            \t\t}
            \t}
            \tif len(Fill(0)) != 0 {
            \t\tt.Error("n == 0 should return an empty slice")
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let rangeAndClose = Lesson(
        id: "concurrency.range-and-close",
        title: "range over a channel ends when it closes",
        objective: "Drain a channel with range, and close it from the sender.",
        explanation: """
        The Tour's "Range and Close" page: `v, ok := <-ch` sets ok to false \
        once the channel is closed and empty. `for v := range ch` is that \
        loop written once. Only the sender closes. Sending after a close \
        panics. Closing is not required for the garbage collector — only \
        for telling a range there is nothing more.

        Channels are not files. Most of them never close, because nobody is \
        ranging. Close when a range (or an ok-receive) needs the signal.
        """,
        conceptTags: [GoConcept.rangeOverChannel, GoConcept.channelClose],
        task: .compile(
            starter: """
            package main

            // Drain reads every value until ch closes and returns them in
            // the order they arrived.
            func Drain(ch <-chan int) []int {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestDrainReadsUntilClose(t *testing.T) {
            \tch := make(chan int, 3)
            \tch <- 2
            \tch <- 4
            \tch <- 6
            \tclose(ch)
            \tgot := Drain(ch)
            \tif len(got) != 3 || got[0] != 2 || got[2] != 6 {
            \t\tt.Fatalf("got %v, want [2 4 6]", got)
            \t}
            \tif len(Drain(closedEmpty())) != 0 {
            \t\tt.Error("an already-closed channel should drain as empty")
            \t}
            }

            func closedEmpty() <-chan int {
            \tch := make(chan int)
            \tclose(ch)
            \treturn ch
            }
            """
        ),
        idiomaticSolution: """
        func Drain(ch <-chan int) []int {
        \tout := []int{}
        \tfor v := range ch {
        \t\tout = append(out, v)
        \t}
        \treturn out
        }
        """
    )

    static let selectDefault = Lesson(
        id: "concurrency.select-default",
        title: "default makes select try, not wait",
        objective: "Receive from a channel if a value is ready, and return if it is not.",
        explanation: """
        The Tour's "Default Selection" page: a `default` case runs when no \
        other case is ready, so the select returns instead of blocking. That \
        is how you poll a channel, and how you try a send without parking \
        the goroutine.

        Without default, select waits. With it, "nothing ready" is a value \
        you handle, not a hang. A busy loop of default-selects is a spin; \
        use it for a single try, not as a substitute for a timer.
        """,
        conceptTags: [GoConcept.selectDefault, GoConcept.selectBranch],
        task: .compile(
            starter: """
            package main

            // TryRecv returns the next value and true when one is ready,
            // or 0 and false without waiting.
            func TryRecv(ch <-chan int) (int, bool) {
            \treturn <-ch, true
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestTryRecvDoesNotBlock(t *testing.T) {
            \tempty := make(chan int)
            \tif _, ok := TryRecv(empty); ok {
            \t\tt.Fatal("an empty channel is not ready")
            \t}

            \tready := make(chan int, 1)
            \tready <- 7
            \tv, ok := TryRecv(ready)
            \tif !ok || v != 7 {
            \t\tt.Fatalf("got %d, %t; want 7, true", v, ok)
            \t}
            \tif _, ok := TryRecv(ready); ok {
            \t\tt.Fatal("the channel should be empty after one receive")
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func TryRecv(ch <-chan int) (int, bool) {
        \tselect {
        \tcase v := <-ch:
        \t\treturn v, true
        \tdefault:
        \t\treturn 0, false
        \t}
        }
        """
    )

    static let directionalChannels = Lesson(
        id: "concurrency.direction",
        title: "The arrow in the type is who may send",
        objective: "Write a producer that takes chan<- int and closes it.",
        explanation: """
        The Tour writes `ch <- v` and `v := <-ch` and then, in Effective Go, \
        the type itself carries the arrow: `chan<- int` is send-only, \
        `<-chan int` is receive-only. A function that only produces values \
        should take `chan<- T`. The compiler then refuses a receive in that \
        body, which is the whole point — the restriction is the API.

        Conversion is one way: a bidirectional channel may be passed where \
        a directional one is wanted. The other direction does not compile. \
        Close is a send-side operation, so it belongs on `chan<- T`.
        """,
        conceptTags: [GoConcept.channelDirection, GoConcept.channelClose],
        task: .compile(
            starter: """
            package main

            // Produce sends every value and then closes out. The parameter
            // is send-only: a receive in this function should not compile.
            func Produce(out chan<- int, values []int) {}

            func main() {}
            """,
            hiddenTest: """
            package main

            import "testing"

            func TestProduceSendsAndCloses(t *testing.T) {
            \tout := make(chan int, 4)
            \tProduce(out, []int{1, 3, 5})
            \tvar got []int
            \tfor v := range out {
            \t\tgot = append(got, v)
            \t}
            \tif len(got) != 3 || got[0] != 1 || got[2] != 5 {
            \t\tt.Fatalf("got %v, want [1 3 5]", got)
            \t}
            }

            func TestProduceAcceptsSendOnly(t *testing.T) {
            \t// If Produce takes chan int instead of chan<- int this still
            \t// compiles, but the lesson's idiomatic answer is the type.
            \tout := make(chan int)
            \tgo Produce(out, nil)
            \tfor range out {
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Produce(out chan<- int, values []int) {
        \tdefer close(out)
        \tfor _, v := range values {
        \t\tout <- v
        \t}
        }
        """
    )
}
