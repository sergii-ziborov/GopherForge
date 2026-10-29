## Start with the rule the state must preserve

A service passes its race-detector tests, yet occasionally loses an increment, oversells a limited work slot, or publishes mismatched configuration fields. The first instinct is often to add another lock or replace a map with sync.Map. Before choosing a primitive, write down the invariant: the relationship that must remain true after every accepted operation.

For a counter, two accepted increments should produce an increase of two. For a reservation, accepted units must not exceed available units. For a configuration snapshot, a version and its associated limits should belong to the same publication. These are application rules. A synchronization primitive helps implement them, but it cannot infer which separate method calls the application intended to treat as one operation.

This guide uses an original standard-library lab to separate memory safety, operation atomicity and ownership. Its controlled lost-update example deliberately uses synchronized accesses throughout. We checked the correct implementation and its demonstrations with native Go 1.27.3, repeated tests and the race detector. There are no timing-based benchmark claims: the point is a reproducible semantic failure and a testable repair.

## A race-free read and write can still lose an update

The lab's Counter has Load and Store methods, each protected by the same mutex. Two goroutines call Load, calculate the next value, then call Store. A channel barrier guarantees that both loads observe zero before either store begins. Both goroutines therefore store one, and the final count is one.

| Controlled step | Goroutine A | Goroutine B | Stored value |
| --- | --- | --- | ---: |
| Initial state | Waiting | Waiting | 0 |
| Read separately | Reads 0 | Reads 0 | 0 |
| Calculate locally | Computes 1 | Computes 1 | 0 |
| Store separately | Stores 1 | Stores 1 | 1 |

Every access to the shared integer is locked. The failure is the gap between the protected operations, not a broken mutex. The [Go memory model](https://go.dev/ref/mem) describes synchronization relationships; our application still needs to choose the operation those relationships protect.

The fixture is deterministic because it coordinates the reads explicitly. It does not increase loop counts until a failure happens or insert sleeps in the hope of making the scheduler cooperate. A single run explains the result. That makes the example useful in code review: a reviewer can point to the exact interval in which another operation invalidates the caller's assumption.

## Protect the complete transition

The correct increment holds one lock across reading and updating the value. The caller asks for an increment rather than assembling that operation from independently synchronized getters and setters. The API now expresses the intended transition.

```go
func (c *Counter) Add(n int) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value += n
}
```

The distinction becomes more important for a reservation. A check that there is enough capacity and the subtraction of that capacity must share a boundary. If those are separate calls, several callers may all receive a positive availability answer before any of them reserves their units.

```go
func (c *Counter) TryReserve(n int) bool {
    if n <= 0 {
        return false
    }
    c.mu.Lock()
    defer c.mu.Unlock()
    if n > c.value {
        return false
    }
    c.value -= n
    return true
}
```

The tests check zero and negative requests, excessive requests, exactly the remaining capacity and competing reservations. A mutex alone does not establish those boundary rules; the checks and state change inside the operation do. For a real capacity service, also define who releases a reservation and how abandoned or expired work is reconciled. The small lab addresses the local transition, not a distributed inventory system.

## Use the race detector for the question it can answer

The [race-detector guide](https://go.dev/doc/articles/race_detector) explains that detection depends on executed code paths. A clean run is useful evidence about those paths. It is not proof that every possible workload is race-free, and it is not a proof of business correctness.

Our lost-update fixture should continue to return one while remaining free of unsynchronized memory accesses. Treating that fixture's successful execution as an application success would miss its purpose. The test names distinguish the deliberately incorrect composition from the complete Add operation that must preserve all increments.

Use different assertions for different questions. Race detection checks memory-access behavior. A reservation test checks accepted capacity. A snapshot test checks whether fields come from one version. An ownership test changes a returned map and checks that internal state did not change. A lifecycle test checks that workers have finished when their owner returns.

Run those checks together, but keep their claims separate in the review. A team that says only all tests passed may accidentally omit the invariant that motivated the change. A stronger report names the accepted transition, the competing callers and the outcome that would demonstrate a defect. The [concurrency-testing guide](/news/go-concurrency-tests-synctest-without-sleeps) shows how explicit coordination helps make those assertions reliable.

## Decide which state belongs under one owner

A cache entry may contain a value, an expiry and an accounting charge. A registry may contain a membership map and a count. Protecting the map while updating the related count under an unrelated lock can expose states that the feature never intended to publish. Start with the relationship, then choose the ownership boundary.

The older [Go maps article](https://go.dev/blog/maps) explains why ordinary maps need appropriate coordination for concurrent access. A lock around the map addresses that access requirement. It does not automatically protect a separate counter, a pointer stored inside a value, or a larger operation that spans several lookups.

Draw the state as a small ownership graph. Which fields change together? Which values can callers retain? Which operation may create or remove an entry? What result should a concurrent reader observe if it arrives between two modifications? Those questions often reveal that a convenient generic Store method is exposing too much of the implementation.

Prefer methods named after useful operations when they clarify the invariant: Reserve, ReplaceConfiguration, CompleteJob or RemoveAndReturn. Avoid promising atomicity for a workflow merely because each helper is individually synchronized. The companion [retry and idempotency guide](/news/go-retries-idempotency-keys-unknown-outcomes) applies the same reasoning to a recorded effect and the receipt used to recognize its retry.

## Choose mutex, RWMutex and sync.Map from the workload

A plain mutex is often the simplest way to keep a compound transition understandable. An RWMutex may help a suitable read-heavy workload, but it changes the locking discipline and should be justified with representative measurements. Counting reader methods is not enough to establish that read-lock coordination will improve an actual service.

The [sync package reference](https://pkg.go.dev/sync) describes sync.Map as a specialized type and identifies its intended workloads. A concurrent map is not a general transaction across multiple entries and external state. A Load followed by a Store still expresses two operations unless the chosen API provides the complete conditional transition you need.

Similarly, LoadOrStore does not automatically make an expensive preparation step outside the call execute once. Several callers can prepare candidate values before one candidate becomes the stored value. If preparation acquires resources or triggers effects, give that work its own ownership and duplicate-suppression policy. Storing one winning value does not undo the losing preparations.

Choose the simplest primitive that enforces the required transition, then measure contention if it matters. This lab does not rank synchronization types by speed. Its evidence concerns values, ownership and controlled interleavings. The [lock-ownership lesson](/learn/concurrency.lock-ownership) connects those decisions to copy rules and pointer receivers.

## Atomic publication does not freeze the published object

An atomic pointer can publish a completed configuration so readers observe one selected pointer value. The [atomic package](https://pkg.go.dev/sync/atomic) defines its synchronization semantics. Those semantics do not make later ordinary mutations of the pointed-to map safe, and they do not turn several unrelated loads into one application snapshot.

Our ConfigStore constructs a fresh configuration and never modifies that published version afterward. Writers serialize the read-copy-patch-publish sequence with a mutex, preventing two writers from silently replacing each other's patches. Publication uses an atomic pointer; writer coordination remains explicit.

```go
s.writers.Lock()
defer s.writers.Unlock()
next := clone(old.rates)
for key, value := range patch {
    next[key] = value
}
s.active.Store(&config{rates: next})
```

This is an excerpt; the downloadable implementation also handles the initial empty state. The patch map must remain unchanged by its caller during the call. After the operation returns, callers may change their own inputs without mutating the published configuration because the store owns separate map storage.

The design is not presented as a universal lock-free optimization. It still copies data and allocates, and the runtime has its own costs. Readers do not acquire the writer mutex in this implementation, but a performance claim would require measuring the actual read and update workload.

## A snapshot must preserve one version and its ownership

Reading the version with one load and the limit with another can observe two different publications. If a reader needs a coherent pair, acquire one snapshot for the operation and read both values from it. The lab's Snapshot method loads one configuration pointer and returns an independent copy of that version's map.

```go
func (s *ConfigStore) Snapshot() map[string]int {
    v := s.active.Load()
    if v == nil {
        return map[string]int{}
    }
    return clone(v.rates)
}
```

The tests update version and limit together while readers verify that limit equals ten times version. Another test mutates the constructor's input and a returned snapshot, then verifies that the store's state is unchanged. The second test catches a different class of defect from a mixed-version read: a caller receiving mutable ownership of internal state.

The [maps.Clone documentation](https://pkg.go.dev/maps#Clone) is a useful reminder that an outer map copy is shallow. Our map values are integers, so copying those values establishes the independence this example needs. If a configuration contains slices, pointers or nested maps, define the ownership of those inner objects separately. Copying one container does not recursively make the entire graph immutable.

For the lifetime consequences of shared references, continue with the [heap-graph guide](/news/go-heap-graphs-reachability-retained-memory) and [atomic snapshot lesson](/learn/concurrency.atomic-snapshots).

## Keep blocking work outside a local state transition deliberately

Holding a mutex while waiting for a slow dependency can extend contention and make cancellation or shutdown harder to reason about. Simply unlocking before the dependency call, however, may reopen the exact invariant gap the mutex was intended to close. The solution is to model the intermediate state rather than pretend the whole workflow disappeared.

A job manager might reserve a slot under the lock, release the lock while doing external work, then finalize that specific reservation under the lock. It needs an operation identifier, a cancellation path and a rule for releasing abandoned capacity. Another caller must not mistake reserved-but-unfinished work for available capacity or a completed result.

If the process can restart, local mutex ownership is not enough to recover that intermediate state. Persisted workflows and external effects require additional records and reconciliation. The local critical section and the distributed operation are different boundaries, even when the function that coordinates them has one convenient name.

The [bounded-work article](/news/go-backpressure-concurrency-limits-queues-deadlines) covers admission and waiting budgets. Combine those limits with a clear state machine: admitted, reserved, completed, rejected or uncertain. This makes it possible to decide what a timeout changes and what another participant is allowed to retry.

## Channels can express ownership, but they do not copy it for you

A single goroutine processing commands can own a map and its related counters. That can make a complex transition easier to serialize. Send the complete intended command, not a read request followed later by a separate write that assumes the answer is still current. The operation boundary still matters even when there is no shared-map lock in the caller.

Sending a slice or map through a channel also does not automatically create independent backing storage. Decide whether the sender transfers ownership, shares immutable data, or retains a mutable copy. A channel provides communication; the API must provide the lifetime and mutation contract.

Bound the command queue and define what happens when the owner stops. A caller waiting forever for a reply is not a successful ownership design merely because all map accesses occur in one goroutine. Cancellation, rejection and joining need explicit paths.

Use the [mutex-or-handoff lesson](/learn/concurrency.mutex) and [cancel-and-join lesson](/learn/concurrency.cancel-and-join) together. They help distinguish state protection from lifecycle completion. A worker that has received a cancellation signal may still be using its state, so cleanup should follow evidence of completion rather than the existence of a signal alone.

## Preserve the synchronization object's identity

Types containing active mutexes or atomic state should not be casually copied after use. Pointer receivers and constructors returning pointers help make the intended identity visible, but callers and helper functions still need to respect it. A value copy can separate the lock from the state relationships the original object was supposed to protect.

Run go vet as part of the review and inspect copy-lock diagnostics when they appear. The [vet command reference](https://pkg.go.dev/cmd/vet) describes its role as a checker for suspicious constructs. Static checks complement tests; they do not replace a review of the actual ownership contract.

Avoid returning internal map storage just to make a getter cheap. If copying snapshots is too expensive for a measured workload, choose another explicit interface, such as a read-only operation over one internally retained version. Consider how that interface prevents references from escaping and whether callbacks can block or reenter the owner.

A useful optimization preserves the invariant while changing its cost. Removing ownership boundaries to improve a microbenchmark changes the API's behavior, not just its implementation. The [allocation-profiling guide](/news/go-allocation-profiling-pprof-escape-benchmarks) shows how to separate measured resource improvements from changes to the output contract.

## Explore the interleaving in Playground

[Download the synchronization and retry lab](/downloads/go-reliability-lab-20261029.zip). The invariants/main.go program is self-contained and uses standard-library packages. Before replacing an existing [Playground](/playground) draft, download your source copy. Paste the program into main.go and keep a compatible go.mod. The browser editor does not execute Go or automatically create a room.

Predict the controlled lost-update result before running. Replace the composed Load and Store calls with one complete Add and compare the result. Change the reservation request to exactly the remaining capacity, then one unit above it. Mutate the returned snapshot and check whether a later snapshot changes. Each mutation should test one named contract.

If you choose to collaborate, create a temporary room, open it in a compatible GopherForge native app and press Run on the device where the code should execute. Other participants receive output attributed to that device and source revision. The [MCP guide](/guide/mcp) explains link roles, expiry and how Claude or Codex can help edit. AI edits do not automatically run the program.

The complete suite adds repeated concurrent callers, coherent snapshot checks and deliberately broken negative variants. Run go test -race -count=50 ./... and go vet ./... from the downloaded module. The standalone programs also cross-compile for wasip1/wasm; that build check is separate from certifying every host's runtime behavior. The goal is a clear invariant, a controlled competing operation and evidence that the implementation preserves the rule the feature actually needs.
