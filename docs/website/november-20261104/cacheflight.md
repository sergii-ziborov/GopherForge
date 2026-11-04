## A fast cache can still overload the database

A popular record expires, many handlers miss the cache at the same moment, and each handler starts the same expensive database query. Redis can answer the misses quickly while the application becomes less healthy. Increasing the Redis connection pool does not solve the duplicated backend work. The missing part is a policy for coordinating fills, bounding admitted work and deciding what happens while a value is unavailable.

This is the **1 November 2026 archive edition**, researched and first published on **4 November 2026**. It includes an original Go lab using `golang.org/x/sync` v0.24.0 under Go 1.27.3. The lab proves specific local coordination and cancellation behavior with synthetic loaders. It does not start a Redis server or claim a production throughput improvement. Redis deployment behavior still needs integration testing against the topology and client configuration you operate.

The useful design separates three mechanisms: a cache stores results for some period, duplicate suppression joins equivalent work that is currently running, and admission control limits work across distinct keys. A service may need all three. Combining their names into a helper called `GetOrLoad` does not make their contracts disappear. Write down each responsibility before deciding where the helper belongs.

## Distinguish a miss, an outage and a rejected request

A missing key is an expected cache outcome. A timeout, authorization failure or connection error is a different event. Treating every error as a miss can redirect an entire cache outage into the primary database. The application may then overload the dependency that the cache was meant to protect. The fallback policy needs a capacity budget, not just an optimistic database call.

Decide which data is eligible for fallback and how much additional work the backend can accept. Some reads can return a previously approved stale value. Some can fail promptly with a retryable application response. Authorization decisions or rapidly changing ownership information may require a stricter policy. The decision should follow the data's meaning rather than the convenience of one shared cache wrapper.

Instrument the outcomes separately. A single cache-hit percentage cannot show whether misses were ordinary expirations or failures in the cache path. Count loader starts, coalesced waiters, rejected fills and backend completions. Keep keys and values out of metric labels when they create unbounded cardinality or expose data. The [Go overload guide](/news/go-backpressure-concurrency-limits-queues-deadlines) explains why useful completions and bounded waiting matter more than accepting every request into a growing queue.

## Lookup, coalesce, bound and publish

Start with a normal lookup. On an eligible miss, join equivalent in-flight work within the chosen coordination boundary. The shared loader needs its own finite budget and access to a bounded backend. After successful loading, publish an appropriate cache value with an intentional expiration policy. A failed or invalid result must not become a successful cached entry merely because the loader completed.

The [singleflight package](https://pkg.go.dev/golang.org/x/sync/singleflight) suppresses duplicate calls for a key within a group. It does not store a result after the call finishes. A later request may start new work unless a separate cache lookup succeeds. It also does not coordinate independent processes, and it cannot decide whether two callers are authorized to receive the same result.

In a cache-aside implementation, check the cache again inside the winning loader if another process could have filled it between the first miss and loader execution. Keep that second lookup within the shared budget. Then load only if the value is still absent under the selected policy. This closes one avoidable duplication window, while acknowledging that multiple replicas can still perform simultaneous fills. The four-stage workflow helps reviewers see exactly which race a mechanism addresses and which races remain outside its boundary.

## A key is a statement about equivalence

Duplicate suppression is safe only when equal keys mean that sharing the result is valid. A resource ID alone may be insufficient when the answer depends on tenant, authorization scope, locale, feature version or requested projection. An incorrectly broad key can return a perfectly fresh value to the wrong caller. This is a semantic failure that an excellent cache-hit rate would not reveal.

Build keys from a documented schema and version that schema when its meaning changes. Avoid inserting raw authorization tokens into keys or logs. Include the minimum stable attributes needed to distinguish permissible results. If a callback reads additional request-local state that is absent from the key, the apparent equality of keys may be misleading. Review the key and loader inputs together.

Tests should include two requests that look similar but must remain separate. For example, two tenants can use the same local record number while referring to different records. Another useful fixture changes the projection version while leaving the resource ID unchanged. A correct shared loader should not quietly combine those operations. This is a better correctness test than proving only that twenty identical public-data requests can share one synthetic computation.

## Separate the caller's patience from shared work ownership

A handler may stop waiting because its client disconnects. That does not necessarily mean every other caller waiting for the same public value should lose the shared result. Conversely, detaching shared work from every request without giving it an owner can create background work that survives indefinitely. The design needs both an independent loader budget and a way for each caller to stop waiting.

The lab creates the loader context from an explicit application-owned background context with a finite timeout. It deliberately does not inherit arbitrary values from the first request. Each waiter selects between its own context and its result channel. In a service, also connect shared work to the process lifecycle so shutdown can stop new fills and wait for or cancel outstanding work according to a defined grace period.

The [context package](https://pkg.go.dev/context) supplies cancellation primitives, but it does not assign ownership for you. A child context cannot extend an already expired request budget. A detached context cannot enforce a meaningful lifetime unless another owner supplies one. Our [deadline diagnosis article](/news/go-context-deadline-exceeded-timeout-diagnosis) provides the complementary workflow for identifying which budget actually expired and what work remains after a caller returns.

## Test a canceled waiter while another waiter succeeds

The original coordination test starts a loader behind a controlled gate, registers two waiters for the same key and cancels one waiter's context. That waiter returns a cancellation error. Opening the gate then allows the other waiter to receive the result. Another test registers twenty duplicate calls before releasing the loader and verifies that the callback ran once. These are controlled correctness observations, not HTTP load-test results.

The waiting function receives one result rather than ranging over the channel:

```go
select {
case <-ctx.Done():
    return "", ctx.Err()
case result := <-ch:
    if result.Err != nil {
        return "", result.Err
    }
    return result.Val.(string), nil
}
```

The complete lab checks an already canceled context before this select and controls which values its loader can produce. The package documentation states that a `DoChan` result channel is not closed. Ranging over it would therefore add an incorrect completion assumption. A canceled waiter may leave its buffered result unread; that does not imply that the shared operation should be canceled for the remaining waiters. This is exactly the sort of small lifecycle detail that deserves a targeted test.

## TTLs define freshness windows, not coordination

An expiration says when a cached value should stop being considered available under a particular cache policy. It does not prevent many clients from noticing that expiration simultaneously. If many popular keys share an identical lifetime and are populated together, synchronized expiry can concentrate backend work into bursts. Modest bounded jitter can spread some refresh demand, but it does not replace a backend concurrency limit.

The [Redis SET documentation](https://redis.io/docs/latest/commands/set/) specifies atomic value-setting options and expiration forms. Choose the operation that establishes the value and its intended lifetime together rather than relying on a separate expiration command that might never execute after a failure. Also check how overwriting a key affects its lifetime under the chosen options. A refactor that accidentally removes expiration can turn a freshness policy into permanent retention.

Treat zero, negative and extreme TTL values as explicit configuration cases. Validate them before turning durations into client arguments. For a teaching exercise, write a table that distinguishes absent, fresh, stale-but-eligible and rejected values. Then assign each state a caller-visible result. This makes it possible to discuss freshness precisely without pretending that one timeout value answers every availability or correctness requirement.

## Process-local suppression is not a distributed lock

Each replica has its own memory and its own singleflight group. A deployment with several replicas can therefore perform several fills for one key even when each replica suppresses its own duplicates correctly. Decide whether the backend can tolerate that bounded duplication before introducing a distributed coordination mechanism. A distributed lock has its own failure, ownership and recovery requirements.

The [Redis distributed-lock discussion](https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/) is useful for understanding leases and safe ownership-aware release. Do not translate a short lock example into a universal exactly-once guarantee. A lease can expire while a paused owner still believes it holds authority. Whether an old owner's later write is acceptable depends on the protected operation and any fencing or version checks at the resource being modified.

For a cache fill, duplicate read work may be acceptable while duplicate external side effects are not. Keep those cases separate. Loading a public catalog value and issuing an irreversible command should not share the same retry assumptions. If a fill callback performs a durable effect, review idempotency and the uncertain-outcome path explicitly. The [retry and idempotency guide](/news/go-retries-idempotency-keys-unknown-outcomes) explains why a repeated call can be safe only when the effect's identity and recovery contract support it.

## Bound distinct keys as well as duplicate keys

Singleflight helps when many callers request equivalent work. It does little for a surge of unique keys. An attacker or an ordinary broad report can still create many simultaneous loaders, each retaining input, a context, a result channel and backend resources. The number of distinct in-flight keys is therefore an operational quantity worth bounding and observing.

Place admission control around the actual expensive stage. Choose whether capacity is global, per tenant or partitioned by backend. Keep the wait finite, and avoid making rejected callers immediately retry in a synchronized loop. If a loader occupies a slot while waiting for another bounded queue, include that nested waiting in the capacity model. Otherwise several individually reasonable limits can combine into a system that spends most of its budget waiting.

Connection pools are another boundary, not a substitute for all upstream control. Reusing a Redis client and understanding its pool is sensible, but increasing pool size can increase concurrent demand on Redis and the origin database. Record what is actually saturated before changing a limit. The [Redis capacity lesson](/learn/services.redis-capacity) and [Redis under-load lesson](/learn/datastores.redis-load) connect these decisions to practical service behavior.

## Mutable results need an ownership policy

The lab returns immutable string values to keep the sharing contract simple. A real loader might return a slice, map or pointer to a document. Every waiter can then receive a reference to the same underlying object. If one caller modifies it, another caller may observe the change or participate in a data race. Duplicate suppression does not make shared mutable data safe.

Choose immutable result types, copy at an appropriate boundary or document a synchronization rule that every caller can actually follow. Be precise about shallow and deep copies. Copying an outer slice does not detach nested maps or pointed-to objects. If a result is also retained by a local cache, include the cache's ownership in the same analysis rather than treating it as a separate implementation detail.

The [borrowed-buffer guide](/news/go-bytes-buffer-sync-pool-ownership) provides useful examples of storage that becomes unsafe after reuse. Adapt that reasoning to coalesced results: which owner can modify this object, how long can waiters retain it, and when can the storage be reused? A small correctness test that mutates one returned value can expose assumptions that a successful high-concurrency run would miss. A race-free test run alone does not establish immutability; it only observes the schedules and paths exercised.

## Do not publish an old fill over a newer value

Coalescing duplicate reads does not decide how a concurrent write interacts with an in-flight fill. Consider a loader that reads version one, then pauses while another request writes version two and invalidates the cache. If the old loader later publishes its earlier result, the cache can become stale immediately after the write path appeared to invalidate it successfully. No simultaneous duplicate fill is required for this race.

Define the version relationship between the authoritative record and the cached derivative. Depending on the application, a versioned cache key, an ownership-aware conditional publication or a deliberate bounded-staleness contract may be appropriate. The choice needs to match how readers discover the current version and how older entries expire. Simply adding a distributed lock around the read does not automatically cover a writer that follows a different protocol.

Test the interleaving explicitly with a controlled gate: capture an old result, perform the newer write, release the old loader and inspect what later readers receive. Keep the assertion tied to the selected freshness policy. If stale values are permitted for a bounded interval, say so. If they are forbidden after the write acknowledgment, the publication protocol must protect that stronger invariant. This is another reason to review cache fills and invalidation together rather than optimizing their helpers independently.

## Run a bounded experiment before tuning production

[Download the engineering lab](/downloads/go-engineering-lab-20261104.zip) and run `go test -race ./cachelab`. The pinned module and checksum file make the example reproducible after dependencies are installed. Initial dependency setup may need network access; the recorded test suite also runs from a populated cache with module downloads disabled. No Redis server is required for these particular coordination tests.

Read the tests before altering the helper. Predict what happens when one waiter cancels, when the shared budget expires and when the loader returns an error. Then add a distinct-key admission policy and verify it with explicit barriers rather than arbitrary sleeps. Keep integration tests for the real Redis client separate so connection, expiration and topology behavior remain visible rather than being inferred from the synthetic fixture.

The [cache-aside lesson](/learn/datastores.redis-cache) offers a shorter guided route. A compatible example can be discussed in [Playground](/playground), with the [MCP guide](/guide/mcp) explaining how an assistant can inspect shared source and observed output. Before claiming a production improvement, compare useful backend completions, queue time, rejected work and freshness under a representative workload. The result should be a cache policy whose failure modes you can explain, not merely a more impressive hit-rate graph.
