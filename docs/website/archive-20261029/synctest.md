## Replace timing guesses with observable contracts

A concurrent test that occasionally fails in CI is not merely annoying. It makes every failure harder to interpret: a real regression can be dismissed as another scheduling accident, while an arbitrary timeout increase can hide the condition the test was meant to expose. Reliable concurrency tests begin by deciding what must happen before an assertion is allowed to run.

Consider a small delayed notification component. It must not produce a value before a deadline, it must produce one value afterwards, and cancellation before the deadline must stop it without producing a value. Those are three different claims. A test that waits one second and checks a shared boolean may establish none of them, especially when it also accesses that boolean without synchronization.

This guide develops a complete small example using channels and testing/synctest, then separates its guarantees from race detection and integration testing. The examples target the stable Go 1.25-or-later Test API and were checked with a native Go 1.27.3 toolchain. They do not require a live network, database or cloud service. For the app's different execution environment and limits, see the [GopherForge guide](/guide); native desktop verification is not a claim that every operating-system integration runs unchanged inside the app sandbox.

## Write down the event that makes an assertion legal

Before choosing a test tool, describe the lifecycle in observable terms. When is the worker started? What proves that it has accepted an input? What signals that a result is available? What tells the owner that cancellation has completed? These questions often reveal that the production API itself lacks a useful ownership boundary.

A start channel, a completion channel or a returned result channel can provide concrete evidence. A sleep provides elapsed time, which is different evidence. Even a large delay does not force a heavily loaded machine to schedule a particular goroutine before the test continues. A machine being fast enough yesterday is not part of a concurrency contract.

Keep test instrumentation small and tied to a real boundary. It can be appropriate to inject a narrow dependency that reports an operation starting, but avoid adding a maze of test-only sleeps and global flags throughout production code. Prefer an API whose owner can already observe completion. That makes both the implementation and its tests easier to shut down correctly.

Use the [cancel-and-join lesson](/learn/concurrency.cancel-and-join) to review the owner relationship. A useful exercise is to draw one arrow for starting work and a second arrow for observing its end. If the second arrow has no endpoint, the test may be trying to compensate for a missing lifecycle contract.

## Understand what a synctest bubble controls

The stable testing/synctest API runs a test function and the goroutines it starts inside an isolated bubble. Time inside that bubble is virtualized. This allows tests to explore timers and deadlines without making the developer wait for equivalent wall-clock durations. It is particularly useful when the behavior of interest is a relationship between time and local asynchronous work.

The official [package reference](https://pkg.go.dev/testing/synctest) defines which operations count as durably blocked and how Wait behaves. Do not replace those rules with the assumption that any blocked goroutine makes the bubble idle. External operating-system activity and goroutines created outside the bubble can change what the test can control.

The Go team's [Testing Time article](https://go.dev/blog/testing-time) explains the design motivation. The practical engineering rule is to keep the component under test self-contained: local goroutines, explicit channels and controlled dependencies. A bubble is not a virtual Kubernetes cluster, a database simulator or an exhaustive model checker for every scheduler interleaving.

Older experimental examples used a different API. Use the stable Test API for this guide, and check the selected toolchain with go version before copying code from an older article. The [Go 1.25 release notes](https://go.dev/doc/go1.25) document that transition. A version mismatch is a tooling problem to resolve, not a reason to silently rewrite the test's intended contract.

## Give the delayed operation one owner and one result channel

This helper creates one timer and one goroutine. Its caller owns cancellation. The goroutine owns closing the result channel and stops its timer on every return path. A successful notification uses an unbuffered send so that the receiver's acceptance is explicit; the send also observes cancellation if the receiver has left.

```go
func delayed(ctx context.Context, after time.Duration) <-chan string {
    out := make(chan string)
    go func() {
        defer close(out)
        timer := time.NewTimer(after)
        defer timer.Stop()
        select {
        case <-ctx.Done():
            return
        case <-timer.C:
        }
        select {
        case out <- "ready":
        case <-ctx.Done():
        }
    }()
    return out
}
```

The helper does not promise which outcome wins if cancellation and delivery become possible at the same instant. That is a separate API design decision. If a business operation needs stronger ordering, represent the decision with a single owner and an explicit state transition rather than assuming select gives cancellation priority.

A buffered output could also be reasonable, but it would change the completion and delivery contract. Choose it because callers benefit from that behavior, not merely because a test otherwise hangs. Similarly, closing the channel from the caller would violate the producer's ownership and could panic when the worker sends. The small helper is useful because these decisions remain visible.

## Test the boundary before and after the deadline

The first test establishes that the component has settled, checks that it has not produced an early result, advances virtual time to just before the deadline, and checks again. Only after crossing the boundary does it accept the expected value. The nanosecond is a precise boundary in this synthetic example, not a production latency objective.

```go
func TestDelayedBoundary(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        ctx, cancel := context.WithCancel(context.Background())
        defer cancel()
        out := delayed(ctx, 5*time.Second)
        assertEmpty := func() {
            t.Helper()
            select {
            case v, ok := <-out:
                t.Fatalf("early result: %q open=%v", v, ok)
            default:
            }
        }
        synctest.Wait()
        assertEmpty()
        time.Sleep(5*time.Second - time.Nanosecond)
        synctest.Wait()
        assertEmpty()
        time.Sleep(time.Nanosecond)
        synctest.Wait()
        if v, ok := <-out; !ok || v != "ready" {
            t.Fatalf("result=%q open=%v", v, ok)
        }
        if _, ok := <-out; ok { t.Fatal("extra result") }
    })
}
```

Those sleeps advance virtual time inside the bubble; they are not wall-clock guesses about how long a goroutine might take to start. Wait is used to observe a settled state before making a nonblocking assertion. The final channel receive also makes completion visible. Removing that ownership discipline and merely keeping the same durations would not produce an equivalent test.

If the first assertion fails after changing the implementation to send immediately, the test has detected the intended early-delivery defect. That is much stronger evidence than observing that the original implementation passes repeatedly.

## Cancellation must have an observable end

Cancellation is a request. A reliable test should also establish that the worker acted on it. Here the producer's closed result channel provides that evidence. The test cancels before the timer is due and then verifies that the channel is closed without a delivered value.

```go
func TestDelayedCancellation(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        ctx, cancel := context.WithCancel(context.Background())
        defer cancel()
        out := delayed(ctx, time.Hour)
        synctest.Wait()
        cancel()
        synctest.Wait()
        if v, ok := <-out; ok {
            t.Fatalf("notification after cancellation: %q", v)
        }
    })
}
```

The hour makes the intended ordering obvious: cancellation occurs before the notification deadline in virtual time. The test does not wait an actual hour. It also does not prove a stronger promise about a race between cancellation and an already-ready result. Keep that ambiguity documented or design it away if callers require a strict winner.

Review every blocking operation on the cancellation path. A worker can observe context cancellation and still become stuck reporting a final error to an unobserved channel. A helper can close its output while another child goroutine remains alive. For a more complex component, return a separate completion signal or expose an owned StopAndWait operation, then test that complete lifecycle rather than a convenient intermediate flag.

## Synchronization is still a production responsibility

Virtual time does not turn unsynchronized application memory into a safe concurrent design. A test that reads a shared map while another goroutine writes it still needs the relevant synchronization boundary. The [Go memory model](https://go.dev/ref/mem) describes the ordering relationships that make concurrent memory access meaningful.

Use channels, mutexes, atomics or ownership according to the data contract. A channel send and receive can transfer a result, while a mutex can protect a collection accessed repeatedly. An atomic flag is useful for one state observation; it does not automatically protect the mutable object the flag points toward. Match the primitive to the invariant instead of adding one wherever the race detector complains.

Within a synctest bubble, Wait supplies documented synchronization for observations after goroutines have durably blocked. That is a testing facility, not a synchronization operation your production caller can invoke. Production APIs still need the necessary boundaries when the helper runs outside the test harness.

Our example communicates entirely through its result channel and context. That makes its ownership inspectable without relying on a test-only shared boolean. For a larger service, apply the same reasoning to every mutable structure, including registries used only during shutdown and caches updated by background refreshers.

## Keep real I/O in a different test layer

A database query, a DNS lookup or a real socket operation can depend on the operating system, another process and a network. Those dependencies do not become a fully controlled virtual environment because their caller happens to run inside a bubble. Inject a small local substitute when the unit test is about retry timing, scheduling or cancellation decisions.

Keep the interface narrow. A retry component might need a function that returns a result or an error, not an elaborate mock of the entire database driver. Make the substitute report attempts through channels so the test can establish ordering. Supply distinct failures deliberately, including a permanent failure and a context cancellation, rather than making every call succeed after a fixed delay.

Then add integration tests for the real boundary. A loopback HTTP test can verify listener behavior; a disposable database can verify driver cancellation and transaction outcomes; a cluster exercise can verify readiness propagation during rollout. Each layer should state what it controls and what it merely observes.

The standard [httptest package](https://pkg.go.dev/net/http/httptest) is useful for HTTP tests, but even a convenient local server remains a different environment from ingress and load-balancer routing. The [graceful shutdown guide](/news/go-http-graceful-shutdown-kubernetes) shows how to combine explicit local barriers with a separate deployment-level test plan.

## Use negative controls to test the test

A test can be deterministic and still assert the wrong thing. Introduce a small intentional defect, run the relevant test, and confirm that the failure explains the broken contract. Then restore the implementation. This mutation is a local verification technique, not a change to publish in the application.

For the delayed helper, an immediate send should fail the before-deadline assertion. Ignoring cancellation should fail the cancellation case because a notification becomes visible instead of the expected closure. Sending twice should fail the single-result requirement. These are focused negative controls, not a claim that three mutations cover every possible bug.

Look for assertions that survive all of those mutations. A test that checks only that some value eventually arrives may miss both early delivery and duplicate delivery. A test that accepts either a result or a closed channel may not establish cancellation semantics at all. Strengthen the specific contract instead of increasing repetition until a failure appears.

Be careful with intentionally deadlocking mutations. Run them with a bounded test-process timeout and capture the expected failure, so the verification itself does not hang indefinitely. Separate negative-control results from the green suite in your report. A failed mutant test is evidence of detection; a failed unmodified test is an unresolved defect.

## Add race detection without claiming exhaustive proof

The official [race-detector documentation](https://go.dev/doc/articles/race_detector) explains that detection depends on code actually executing. A green race run is useful evidence about those executions, not proof that no race exists in an unvisited path. Deterministic timing tests and race detection therefore answer related but different questions.

```sh
go version
go test ./...
go test -race ./...
go test -race -count=100 ./...
go test -shuffle=on ./...
```

Use repetition and shuffling as supplements. They can expose interactions between tests or code paths, but they do not repair an assertion that lacks a completion boundary. Pin the toolchain and record the package set so another engineer can reproduce the result. A race-enabled binary also has different resource costs from an ordinary build; do not treat its throughput as a production benchmark.

For CI, keep fast contract tests close to each change and run the required integration environments at an appropriate stage. Preserve the failure seed or shuffle information when it is available. An intermittent failure becomes easier to investigate when the report includes the exact command, toolchain and observed transition, rather than only a screenshot of a red job.

## Apply the method to retries, caches and shutdown

The same pattern works beyond timers. For retries, observe each attempt and verify that permanent errors stop the loop. For cache refresh, establish when the new snapshot becomes visible and whether stale readers retain valid ownership. For shutdown, signal that a handler has been admitted, begin draining, and verify that the lifecycle owner waits for its completion.

In each case, distinguish a time boundary from a scheduling boundary. A timer becoming due does not necessarily mean a worker has already published its result. A cancellation function returning does not necessarily mean every child has exited. A cache refresh finishing does not mean a reader stopped using an older snapshot. Make the relevant transition observable before asserting the next state.

These examples are particularly useful in code review because they expose vague API promises. If a reviewer cannot explain which event makes the assertion legal, the implementation may also leave callers guessing about when it is safe to release resources or begin another operation.

Continue with [synctest in the course](/learn/concurrency.synctest), [memory-order interview preparation](/interview/concurrency.memory-order), and [goroutine ownership and leak investigation](/news/go-1-27-goroutine-leak-profiles). Reliable tests do not require pretending concurrency is simple. They require narrowing each claim until its evidence is explicit, its failure is understandable and its dependencies are controlled.

[Download the original compilable examples and tests](/downloads/go-engineering-examples-20261029.zip). The ZIP includes imports, the local regression suite and a README explaining exactly what was verified.
