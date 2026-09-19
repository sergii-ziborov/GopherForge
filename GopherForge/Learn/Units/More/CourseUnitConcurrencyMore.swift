import Foundation

/// Two more for concurrency: when a mutex beats a channel, and the pool shape.
extension CourseUnitConcurrency {
    static let mutexOrChannel = Lesson(
        id: "concurrency.mutex",
        title: "A mutex is for state; a channel is for handing over",
        objective: "Choose between a mutex and a channel for a given problem.",
        explanation: """
        "Share memory by communicating" is good advice and is not a ban on \
        mutexes. A channel moves a value from one goroutine to another. A mutex \
        protects a value that stays where it is. A counter that many goroutines \
        increment is the second thing, and writing it with a channel produces \
        more code that is slower and harder to read.

        The practical shape is a small struct with the mutex beside the data it \
        guards, and every method taking the lock. If the lock is somewhere else \
        from the data, nothing tells the next reader what it protects.
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
        Three rules make a pool terminate rather than hang. The sender closes \
        the input channel when there is nothing more to send. Each worker \
        ranges over that channel, which ends exactly when it closes. And \
        somebody waits for every worker before closing the output, because \
        closing it early would panic a worker mid-send.

        Get any one of the three wrong and the failure is a deadlock or a \
        panic, neither of which points at the line that caused it. Written the \
        right way round it is about fifteen lines and never needs debugging.
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
}
