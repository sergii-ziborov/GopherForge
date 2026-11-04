## Diagnose the work behind a slow query

A Go endpoint is slow, the MongoDB query looks simple, and the first proposed fix is a larger connection pool. The request might actually be waiting for a connection, scanning too many documents, sorting an unsuitable result set, decoding large documents or holding a cursor longer than expected. Increasing the pool can increase concurrent pressure without addressing the stage that dominates the request.

This is the **2 November 2026 archive edition**, first researched and published on **4 November 2026**. It combines MongoDB's primary documentation with an original standard-library Go fixture for cursor ownership and cleanup. The fixture does not connect to a MongoDB deployment. It verifies a narrow consumer contract using a controlled cursor implementation; query plans, server limits and driver integration still require a real deployment test.

Start with a request whose purpose is explicit. Define its filter, sort order, projection, maximum result and deadline. Then trace the stages that can consume that budget. A useful diagnosis identifies which work is expensive and why it is being performed. A generic statement that MongoDB needs tuning is much less useful than a request shape, an observed plan and a resource whose lifetime is known.

## Reuse the client and budget the topology

A database client is usually a long-lived application resource, not something to recreate for every request. The [MongoDB Go connection-pool documentation](https://www.mongodb.com/docs/drivers/go/current/connect/connection-options/connection-pools/) explains that clients maintain pools for servers in their topology. A pool setting therefore needs to be considered alongside topology and replica count, rather than interpreted as one global connection total for the entire deployment.

Imagine several application replicas, each with its own client, while a rolling release temporarily runs both old and new replicas. The potential demand differs from the number written in a single configuration file. Include operational headroom and other applications that share the database. A pool also does not make the server execute queries more efficiently; it governs one part of how the application obtains reusable connections.

Define what happens while waiting for capacity and how request cancellation reaches that wait. Observe acquisition delays separately from query execution and decoding. The [database/sql pool article](/news/go-database-sql-pool-timeouts-transactions) concerns a different client API, but its budgeting questions transfer: which resource is scarce, how long may a request wait, and what useful work completes after a limit changes? Keep driver-specific behavior tied to the version and topology you test.

## Filter, batch, close and explain

Use four checkpoints. Filter for the intended records, request a bounded result shape, release the cursor on every owned exit path, and inspect the actual query plan for representative data. These checkpoints connect application code to database behavior without assuming that one index or one client setting will solve every workload.

Write the request as a small table before implementing it. Include equality predicates, sort fields, any range predicate, the fields returned to the caller and the maximum useful number of records. This makes it easier to distinguish a page of labels from an unbounded export. The two operations may use the same collection while requiring very different resource policies.

The [MongoDB cursor guide](https://www.mongodb.com/docs/drivers/go/current/crud/query/cursor/) describes batched iteration, cursor errors and cleanup. A cursor should not be used concurrently by unrelated goroutines. Decide which function owns it and which function is responsible for closing it. The synthetic lab makes that ownership transfer explicit so tests can observe cleanup after success, cancellation and decoding failure. Server-side query planning remains a separate checkpoint rather than something a fake cursor can prove.

## Design the index with the query shape

An index is not merely a list of fields that appear somewhere in a filter. Field order, sort requirements, selectivity and projection affect whether the chosen index helps the actual operation. The [equality-sort-range guideline](https://www.mongodb.com/docs/manual/tutorial/equality-sort-range-guideline/) explains why equality fields belong first and why the order of sort and range fields can depend on whether avoiding a sort or exploiting a selective range matters more.

Apply the guideline to one concrete request. Suppose a service lists one tenant's recently updated records in a stable order. The tenant predicate is part of the shape, and the sort needs a deterministic tie-breaker if timestamps can match. Record the intended index and test the result order under duplicate timestamps. A pagination implementation that omits the tie-breaker can skip or repeat records even when its average query time looks good.

Use explain output from representative data to investigate documents examined, keys examined and sort behavior. Do not publish an invented winning plan as though it came from production. A small local dataset may make several plans look similar while a skewed tenant distribution exposes very different costs. Also account for write amplification and storage: creating every plausible index can trade one read problem for expensive writes and a larger operational footprint.

## A row limit is only one resource limit

Limiting the number of returned documents is useful, but it does not automatically bound document size, batch memory, server execution time or the bytes already received by the driver. An endpoint returning ten enormous documents can still exceed a practical memory or response budget. A query that returns few rows can still examine many candidates if its filter and index are poorly matched.

Choose a projection that includes only the fields the operation actually needs. Make the result-count policy visible to callers: does exceeding the limit return a partial result with an error, a continuation token or a normal page? These are different contracts. Avoid silently truncating an export while reporting that the complete job succeeded.

Our fixture bounds the number of `Label` values returned to its caller. It explicitly does not claim to bound MongoDB batch memory or server work. This narrow statement makes its tests useful instead of misleading. The same discipline applies when a handler encodes the result to JSON: decide whether a failure after partial work can still produce a complete valid response, and avoid treating a partially written response as an ordinary recoverable return value.

## Close the cursor even when decoding fails

The lab's consumer accepts a cursor interface and takes responsibility for closing it. A deferred cleanup function runs after a successful iteration, a result limit, a decoding error, a cursor error or caller cancellation. It preserves both the primary failure and any cleanup failure through `errors.Join`, so a cleanup problem cannot silently erase the reason the operation stopped.

The cleanup context is created when cleanup begins:

```go
defer func() {
    cleanup, cancel := context.WithTimeout(
        context.WithoutCancel(ctx), time.Second,
    )
    defer cancel()
    err = errors.Join(err, cursor.Close(cleanup))
}()
```

This is a fragment from the named-return function in the download. Creating the timeout at function entry could leave an already expired cleanup budget after a long iteration. Reusing an already canceled request context can also prevent useful cleanup. The fixture verifies that cleanup receives a live finite context after caller cancellation. It is an application-level resource policy, not a claim that every driver operation must always use this exact duration or detachment strategy.

## Keep cursor errors distinct from an empty result

Iteration ending does not necessarily mean the query completed successfully. Check the cursor's error after the loop and preserve cancellation where relevant. An empty successful result, a malformed document and a network interruption can otherwise collapse into the same empty slice. A caller cannot make a sensible retry or user-message decision when these outcomes are indistinguishable.

The tests inject a cursor failure independently of decoding failure. Another test makes both decoding and cleanup fail and checks that the returned error retains both identities. These assertions protect the boundary that the application consumes. They do not attempt to recreate the complete MongoDB driver inside a mock, and they do not establish how a real server behaves during failover.

Review how partial rows are handled. The lab can return rows collected before an error so that the contract remains explicit. A production API might choose to discard those rows and return a failure instead. Either can be reasonable for a specific operation. What is dangerous is accidentally publishing partial data as complete. The [Go error-contract guide](/news/go-typed-nil-errors-as-contracts) helps connect classification, wrapping and caller-visible behavior to these resource-lifecycle decisions.

## Transaction callbacks may execute again

The [driver's WithTransaction contract](https://pkg.go.dev/go.mongodb.org/mongo-driver/v2/mongo#Session.WithTransaction) states that a callback may run multiple times during retry attempts. A callback that sends an external message or performs an unrelated durable effect can therefore repeat that effect even when the database transaction is eventually committed once. Database atomicity does not automatically extend to independent systems called from inside the callback.

Keep retryable database work distinct from external delivery. One design records an outbox entry with the database change, then lets a separate worker deliver it using a stable operation identity and an explicit acknowledgment policy. That worker still needs retry and recovery logic. An outbox is a boundary for reasoning about effects, not a magic exactly-once label that removes every uncertain outcome.

Do not hide an operation error inside the callback and return success merely to keep the code moving. The driver needs the error to determine the transaction outcome and retry behavior. Also use the transaction's intended context for operations that belong to it. The [transaction lesson](/learn/datastores.mongo-transactions) and [idempotency article](/news/go-retries-idempotency-keys-unknown-outcomes) give complementary exercises. Ask what can be repeated, which system owns the durable receipt, and how a caller discovers an outcome after losing a response.

## Put simple invariants in the write predicate

Some updates can express their invariant in one conditional database operation. For example, a versioned record can be updated only when its stored version matches the caller's expected version. The application must inspect whether a document matched, rather than reporting success solely because no transport error occurred. This makes an optimistic-concurrency decision visible instead of implementing an unsafe read-then-write sequence in application memory.

Choose transactions when the invariant genuinely spans the operations that must change together. Do not use them merely to make a sequence look organized. Conversely, do not remove a necessary transaction because a single-record happy path appears to work. Write a competing-operation scenario and identify the exact state that must never become visible. Then choose the smallest supported database mechanism that protects that state.

The [atomic-update lesson](/learn/datastores.mongo-atomic) is a useful starting point. A controlled Go test can model the intended state transition, while an integration test must exercise the actual database predicate and retry semantics. Keep those levels separate in the evidence. A fake returning a successful update count cannot prove that a real filter, collation, index or write concern protects the invariant under concurrency.

## Observe stages without exposing document contents

Useful telemetry can identify pool wait, query execution, cursor iteration, decoding and response encoding as separate stages. Record stable operation names and approved outcome classifications. Raw filters and full documents can contain sensitive or high-cardinality values, and recording them indiscriminately can create a second data-handling problem while investigating the first performance problem.

Prefer an operation catalog that associates a stable name with the known query shape and index expectation. Then correlate a slow request with that name, the selected application version and bounded counts. A trace can show where time was spent, while explain output from a controlled reproduction can show how the database planned the query. Neither replaces the other.

Our [OpenTelemetry guide](/news/go-opentelemetry-tracing-context-propagation) develops context propagation and safe recording in more detail. The [slog article](/news/go-slog-structured-logging-context-redaction) covers structured event fields. For MongoDB, include the lifecycle outcome: was the cursor exhausted, closed early due to the limit, canceled or interrupted? That information helps distinguish a deliberately bounded response from an incomplete operation that happened to return some data before failing.

## Make pagination tokens part of the query contract

A continuation token should describe where a specific ordered query resumes. If the sort uses a timestamp that is not unique, include a stable tie-breaker in both the order and the resume predicate. Otherwise two records with the same timestamp can move across the boundary in a way that repeats or skips results. Write a fixture with equal timestamps before trusting a pagination implementation that works on uniquely ordered sample data.

Bind the token to the filter and ordering semantics it represents. A token from one tenant, projection version or query mode should not silently resume an unrelated request. Validate the decoded fields and apply the normal authorization rules independently of the token. An opaque-looking encoded string is not evidence that its contents are trusted or unmodifiable.

Also choose a policy for concurrent changes. A list that reflects current data while the user moves between pages has different guarantees from an export that needs a stable logical snapshot. Neither can be established merely by replacing an offset with a keyset predicate. Document what insertions, deletions and updates can do between requests, and test a deliberately changing dataset against that promise. This keeps the pagination mechanism connected to user-visible correctness rather than treating it only as a query-speed optimization.

## Use two levels of tests deliberately

[Download the engineering lab](/downloads/go-engineering-lab-20261104.zip) and run `go test -race ./cursorlab`. Its controlled cursor checks result limits, exact-limit success, cleanup after cancellation and preservation of decoding, cursor and cleanup errors. These tests are fast because they exercise consumer ownership directly and do not require credentials or a database process.

Then add integration tests for the actual driver and deployment. Verify the BSON model, query shape, projection, ordering, pagination token, expected index behavior and transaction retry path. Include representative skew rather than only a uniformly tiny collection. Test how deadlines affect pool acquisition and iteration under your selected driver version. Record the versions and topology so a later engineer can reproduce a failure instead of interpreting an unexplained latency chart.

The [MongoDB cursor lesson](/learn/datastores.mongo-cursors) and [index lesson](/learn/datastores.mongo-indexes) provide shorter guided steps. When an AI assistant suggests a larger pool or a new index, ask it to identify the stage and evidence supporting that change. A useful MongoDB optimization ends with a specific request doing less unnecessary work, a clearly owned resource lifetime and a test that would notice the original mistake returning.
