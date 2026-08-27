import Foundation

/// Jobs in, results out, and a context that can stop the whole thing.
///
/// Three goroutines' worth of channel discipline in one small package: the
/// sender closes the input, a waiter closes the output once every worker has
/// stopped, and every send is paired with a cancellation branch.
enum GoExampleProjectPipeline {
    static let pipeline = GoExample(
        id: "project.pipeline",
        title: "Worker pipeline",
        summary: "Jobs in, results out, and a context that stops the whole thing.",
        takeaway: "Close the channel you send on; range over it to know when it ends.",
        conceptTags: [GoConcept.waitGroup, GoConcept.channelClose, GoConcept.contextCancel],
        source: """
        package main

        import (
        \t"context"
        \t"fmt"
        \t"sort"

        \t"example.com/pipeline/internal/pool"
        )

        func main() {
        \tctx := context.Background()

        \tjobs := []int{9, 4, 7, 1, 6, 3}
        \tresults := pool.Run(ctx, jobs, 3, func(n int) int { return n * n })

        \tsort.Ints(results)
        \tfmt.Println(results)
        \tfmt.Println("count:", len(results))
        }
        """,
        expectedOutput: """
        [1 9 16 36 49 81]
        count: 6

        """,
        extraFiles: [
            "internal/pool/pool.go": """
            // Package pool runs work across a fixed number of goroutines.
            package pool

            import (
            \t"context"
            \t"sync"
            )

            // Run applies work to every job, using at most workers goroutines,
            // and returns whatever finished before ctx was cancelled.
            func Run(ctx context.Context, jobs []int, workers int, work func(int) int) []int {
            \tin := make(chan int)
            \tout := make(chan int)

            \tvar wg sync.WaitGroup
            \tfor range workers {
            \t\twg.Add(1)
            \t\tgo func() {
            \t\t\tdefer wg.Done()
            \t\t\tfor job := range in {
            \t\t\t\tselect {
            \t\t\t\tcase out <- work(job):
            \t\t\t\tcase <-ctx.Done():
            \t\t\t\t\treturn
            \t\t\t\t}
            \t\t\t}
            \t\t}()
            \t}

            \t// The sender closes: the workers range over in, and ranging ends
            \t// when the channel closes and not before.
            \tgo func() {
            \t\tdefer close(in)
            \t\tfor _, job := range jobs {
            \t\t\tselect {
            \t\t\tcase in <- job:
            \t\t\tcase <-ctx.Done():
            \t\t\t\treturn
            \t\t\t}
            \t\t}
            \t}()

            \t// And a third goroutine closes out once every worker has stopped,
            \t// which is the only moment it is safe to.
            \tgo func() {
            \t\twg.Wait()
            \t\tclose(out)
            \t}()

            \tresults := make([]int, 0, len(jobs))
            \tfor result := range out {
            \t\tresults = append(results, result)
            \t}
            \treturn results
            }
            """,
            "internal/pool/pool_test.go": """
            package pool

            import (
            \t"context"
            \t"sort"
            \t"testing"
            )

            func TestRunAppliesWorkToEveryJob(t *testing.T) {
            \tgot := Run(context.Background(), []int{1, 2, 3}, 2, func(n int) int { return n + 10 })

            \tsort.Ints(got)
            \twant := []int{11, 12, 13}
            \tif len(got) != len(want) {
            \t\tt.Fatalf("got %v, want %v", got, want)
            \t}
            \tfor i := range want {
            \t\tif got[i] != want[i] {
            \t\t\tt.Errorf("got %v, want %v", got, want)
            \t\t\tbreak
            \t\t}
            \t}
            }
            """,
        ],
        modulePath: "example.com/pipeline"
    )
}
