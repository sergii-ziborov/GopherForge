import Foundation

/// Two more for concurrency: when a mutex beats a channel, and the pool shape.
extension CourseUnitConcurrency {
    static let mutexOrChannel = Lesson(
        id: "concurrency.mutex",
        title: "A mutex is for state; a channel is for handing over",
        objective: "Choose between a mutex and a channel for a given problem.",
        explanation: """
        A channel is useful for transferring values and coordinating ownership. A mutex protects shared state that remains in place. Choose the mechanism that makes the invariant and its owner easiest to understand; neither mechanism is always faster.

        Keep the mutex next to the data it protects and use the same locking rule for every read and write participating in the invariant. A small, clearly bounded critical section is easier to maintain than a lock whose protected state is scattered.
        """,
        conceptTags: [GoConcept.mutex],
        task: .compile(
            starter: """
            package main

            import "sync"

            // Counter should be safe for many goroutines at once.
            type Counter struct {
            \tmu    sync.Mutex
            \tcount map[string]int
            }

            func NewCounter() *Counter {
            \treturn nil
            }

            func (c *Counter) Add(key string) {}

            func (c *Counter) Get(key string) int { return 0 }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"sync"
            \t"testing"
            )

            func TestCounterIsSafeUnderConcurrency(t *testing.T) {
            \tc := NewCounter()
            \tif c == nil {
            \t\tt.Fatal("NewCounter returned nil")
            \t}

            \tvar wg sync.WaitGroup
            \tfor range 50 {
            \t\twg.Add(1)
            \t\tgo func() {
            \t\t\tdefer wg.Done()
            \t\t\tc.Add("hits")
            \t\t}()
            \t}
            \twg.Wait()

            \tif got := c.Get("hits"); got != 50 {
            \t\tt.Errorf("Get = %d, want 50", got)
            \t}
            \tif got := c.Get("missing"); got != 0 {
            \t\tt.Errorf("an absent key should be 0, got %d", got)
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let workerPool = Lesson(
        id: "concurrency.worker-pool",
        title: "The worker pool, written once",
        objective: "Build a fixed set of workers that finishes cleanly.",
        explanation: """
        A fixed number of workers bounds concurrent processing. The producer sends jobs and closes the input stream after the last job. Workers consume it until it is drained. A coordinator waits for every worker before closing the output stream.

        Results may need to be consumed while jobs are still being produced, or backpressure can deadlock the producer and workers. Add cancellation deliberately, and test termination as well as returned values.
        """,
        conceptTags: [GoConcept.waitGroup, GoConcept.channelClose],
        task: .compile(
            starter: """
            package main

            // Squares runs the numbers through workers goroutines and returns
            // every square. Order does not matter; finishing does.
            func Squares(numbers []int, workers int) []int {
            \treturn nil
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"sort"
            \t"testing"
            )

            func TestSquaresReturnsEveryResult(t *testing.T) {
            \tgot := Squares([]int{1, 2, 3, 4, 5}, 3)
            \tsort.Ints(got)

            \twant := []int{1, 4, 9, 16, 25}
            \tif len(got) != len(want) {
            \t\tt.Fatalf("got %v, want %v", got, want)
            \t}
            \tfor i := range want {
            \t\tif got[i] != want[i] {
            \t\t\tt.Fatalf("got %v, want %v", got, want)
            \t\t}
            \t}
            \tif len(Squares(nil, 2)) != 0 {
            \t\tt.Error("no input should give no results, and should still return")
            \t}
            }
            """
        ),
        idiomaticSolution: """
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
        """
    )

    static let syncOnce = Lesson(
        id: "concurrency.once",
        title: "sync.Once runs a function one time, for everyone",
        objective: "Initialise shared state without a lock you have to remember.",
        explanation: """
        Effective Go and the sync docs: `Once.Do(f)` runs f once, even when \
        many goroutines call Do at the same time. After that, Do is a no-op. \
        It is the right shape for a lazy setup that must not run twice — \
        registering a driver, reading a config, seeding a generator.

        Do not copy an Once after it has been used. Do not call Do with a \
        different f and expect that second f to run. The once is on the Once, \
        not on the function value.
        """,
        conceptTags: [GoConcept.syncOnce, GoConcept.mutex],
        task: .compile(
            starter: """
            package main

            import "sync"

            // Call runs fn through once. Two calls must run fn once.
            func Call(once *sync.Once, fn func()) {
            \tfn()
            }

            func main() {}
            """,
            hiddenTest: """
            package main

            import (
            \t"sync"
            \t"testing"
            )

            func TestCallRunsOnce(t *testing.T) {
            \tvar once sync.Once
            \tn := 0
            \tCall(&once, func() { n++ })
            \tCall(&once, func() { n++ })
            \tif n != 1 {
            \t\tt.Fatalf("n = %d, want 1", n)
            \t}
            }
            """
        ),
        idiomaticSolution: """
        func Call(once *sync.Once, fn func()) {
        \tonce.Do(fn)
        }
        """
    )
}
