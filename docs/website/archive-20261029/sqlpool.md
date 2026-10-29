## When a fast database still produces a slow API

A Go API can time out while its database reports short query durations. The missing time may be spent before the query begins: waiting for a connection, waiting for an application admission slot, or waiting behind work that nobody still needs. Increasing the connection limit treats all three situations as though the database had spare capacity. Sometimes it does. Sometimes the change merely moves the queue into PostgreSQL, makes more transactions compete for the same rows, and increases the cost of every request.

Consider a fictional order service. Its ordinary query takes eight milliseconds in a quiet staging environment, but its production endpoint occasionally takes two seconds. That comparison proves little by itself. Staging might have different data, fewer locks, warmer caches, or no competing reports. The useful investigation follows one request through its actual lifetime: admission, connection acquisition, query execution, result consumption and response writing. A duration measured around the whole repository method includes several of those stages; a database execution statistic may include only one.

This guide builds a concrete operating model for database/sql. The numbers are illustrative budgets, not benchmark results or recommended defaults. The aim is to make capacity and ownership explicit enough that an incident can be explained, reproduced and repaired. Start with the course readings on [pool lifetime](/learn/sql.pool-lifetime) and [rows and cancellation](/learn/sql.rows-and-context) if the API is unfamiliar.

## Budget connections across the entire deployment

A pool belongs to an application process. The database serves the sum of all processes, plus migrations, administration, reporting jobs and other applications. Therefore a per-process setting cannot be evaluated without the maximum number of simultaneous processes. Include rolling-update surge, autoscaling, old replicas that are still draining, and separate worker deployments that use their own pools.

Suppose a database capacity review allocates this application a ceiling of 120 connections. Six ordinary replicas plus two surge replicas, each capped at twelve, can consume 96. Four migration connections and ten reserved for operations bring the planned total to 110, leaving ten as headroom. That is an arithmetic exercise, not evidence that this database should run 110 active queries. Its useful concurrency might be lower because CPU, storage or lock contention becomes limiting first.

Idle connections count inside the open-connection limit; they are not an extra allowance. Likewise, a transaction holding one connection is already part of that process's total. Keep a simple capacity worksheet with the peak replica count, process roles, pool caps and operational reserve. Review it when changing deployment strategy, not just when touching database code.

The official [connection-management guide](https://go.dev/doc/database/manage-connections) explains the pool controls. The engineering decision is how those controls fit your system. A pool cap limits connections, while a separate admission policy limits how much work the service is willing to queue before reaching that pool. Our [backpressure guide](/news/go-backpressure-concurrency-limits-queues-deadlines) develops that second boundary.

## Configure deliberately, then look for evidence

Create one long-lived database handle for a database role and share it between repository operations. Opening a new handle for every request multiplies independent pools and defeats the intended cap. Opening a handle is also different from proving that authentication and connectivity work; perform a bounded readiness check during startup when your availability policy requires it.

```go
func configurePool(db *sql.DB) {
    // Illustrative values: derive these from deployment and DB budgets.
    db.SetMaxOpenConns(12)
    db.SetMaxIdleConns(6)
    db.SetConnMaxIdleTime(2 * time.Minute)
    db.SetConnMaxLifetime(20 * time.Minute)
}
```

Lifetime settings encourage replacement of old connections; they are not a per-query timeout or a promise that a busy connection is interrupted at an exact age. Choose them with knowledge of proxies, server-side idle limits and connection-establishment cost. If reconnects become frequent, investigate the mismatch rather than continually shortening the lifetime.

Document why each setting exists and what would make you change it. For example, a lower idle limit may release expensive idle sessions during quiet periods, while an excessively low limit can create avoidable reconnect churn during bursts. A configuration review should include both a busy period and a quiet-to-busy transition. The correct setting is the one supported by representative observations, not the largest value that avoids an error in a synthetic loop.

## Treat result rows as a resource with an owner

A query has not necessarily finished using its connection when QueryContext returns. The application may still be reading result rows. A repository that returns a raw Rows object transfers cleanup responsibility to its caller, whether the caller understands that contract or not. A repository that materializes a bounded result can keep that responsibility local.

```go
func loadIDs(ctx context.Context, db *sql.DB) ([]int64, error) {
    rows, err := db.QueryContext(ctx,
        `SELECT id FROM orders ORDER BY id LIMIT 100`)
    if err != nil { return nil, err }
    defer rows.Close()

    ids := make([]int64, 0, 100)
    for rows.Next() {
        var id int64
        if err := rows.Scan(&id); err != nil { return nil, err }
        ids = append(ids, id)
    }
    if err := rows.Err(); err != nil { return nil, err }
    return ids, nil
}
```

Here the SQL limit bounds the result size, iteration checks conversion errors, and Rows.Err checks failures that arrive during iteration. The deferred Close protects early-return paths. For write statements that return rows, explicitly consider errors from closing as well; cleanup is not a substitute for checking the operation's outcome.

Avoid performing a slow remote call inside the iteration loop while the database connection remains occupied. If streaming is an intentional requirement, give it its own capacity and cancellation policy. Do not eagerly load an unbounded table merely to release the connection sooner: that trades connection pressure for memory pressure. Pagination, bounded batches and a clear result owner are usually a more useful starting point.

## Give waiting and execution one deadline budget

A request deadline should cover the work the user actually waits for. If a request spends most of its budget waiting for a connection, granting the eventual query a fresh full timeout can extend the operation far beyond that expectation. Propagate the request context, then derive a shorter child deadline only when the database operation deserves a stricter local limit.

The Go guide to [cancelling database operations](https://go.dev/doc/database/cancel-operations) demonstrates context-aware calls. Actual interruption also depends on driver and server behavior. Verify the selected driver against the database you deploy. A context error tells you that a caller's budget ended; it does not independently establish whether a remote write committed.

Always call the cancellation function returned by WithTimeout. Distinguish cancellation by the client, an internal deadline and a database failure in metrics, while returning an appropriate public response without leaking connection strings or SQL parameters. Preserve the causal error for diagnostic code rather than turning every failure into an unstructured message.

An especially revealing test occupies the only permitted connection, starts a second context-aware operation, cancels that operation, and checks that it returns without increasing the pool size. This tests waiting behavior separately from query cancellation. It does not certify the database server's cancellation implementation; that requires an integration test with the real driver and server.

## A transaction must keep all its database work inside

A transaction owns a connection until it finishes. Code that begins a transaction and then calls the original DB handle for a supposedly related operation can acquire another connection and execute outside the transaction. With a one-connection pool it may wait for the connection it is itself holding. With a larger pool it may silently lose atomicity instead of visibly hanging.

```go
func reserve(ctx context.Context, db *sql.DB, sku string) error {
    tx, err := db.BeginTx(ctx, nil)
    if err != nil { return err }
    defer tx.Rollback()

    result, err := tx.ExecContext(ctx,
        `UPDATE stock SET available = available - 1
         WHERE sku = $1 AND available > 0`, sku)
    if err != nil { return err }
    n, err := result.RowsAffected()
    if err != nil { return err }
    if n != 1 { return errors.New("item unavailable") }
    return tx.Commit()
}
```

This PostgreSQL example uses a parameter for the SKU and performs the condition and update in the same statement. It deliberately does not send a notification or call a payment provider inside the transaction. The deferred rollback handles early exits; a successful Commit finishes the transaction first. Review any transaction helper carefully so that it does not hide the commit error or report success before commit completes.

For a multi-step operation, pass an explicit transaction-capable interface or repository bound to that transaction. The [transaction-owner lesson](/learn/sql.transaction-owner) explores that boundary. The official [transaction guide](https://go.dev/doc/database/execute-transactions) is the API reference; your business invariant determines which statements must share the boundary.

## Separate isolation requirements from connection problems

A pool can be healthy while transactions block each other on the database. Increasing pool size then gives more transactions permission to wait on the same contended resource. Inspect the database's activity and wait information alongside application measurements. Ask whether a long-running transaction, an inconsistent lock order or a missing index explains the symptom.

Isolation is a correctness decision. Write down the invariant in a sentence before choosing a level: for example, one inventory unit must not be reserved twice, or a transfer must preserve a defined total. Then identify how the schema, statements, constraints and isolation enforce it under concurrency. A preliminary read followed by an unrelated update is not automatically safe because both statements use a transaction.

PostgreSQL's [isolation documentation](https://www.postgresql.org/docs/current/transaction-iso.html) describes when transactions can be rejected and require another attempt. The response should restart the complete transaction when that is the documented recovery path, not repeat an arbitrary final statement against an aborted transaction.

Also shorten the time between the first statement and commit. Preparing a large response, waiting for a human decision or fetching a remote document inside that interval makes connection ownership and lock duration depend on unrelated systems. Moving that work outside the transaction can be a larger improvement than any pool-setting adjustment. Preserve correctness while changing the boundary; a shorter transaction that loses the invariant is not an improvement.

## Retry an understood outcome, not every error

Retries consume the same scarce connections and execution budget as original attempts. A service that retries three times during a database incident can multiply pressure while telling its caller that it is being resilient. Classify failures using the real driver's error types and database error codes, apply a bounded retry policy only to supported cases, and stop when the parent context is done.

Keep the transaction retry unit separate from externally visible side effects. If an attempt sends an email and then encounters a retryable database failure, a complete retry can send another email. A durable outbox, an idempotency key or an explicitly recoverable workflow may be appropriate, depending on the business action. None is supplied automatically by database/sql.

A commit error deserves special attention. A broken connection while waiting for commit acknowledgement may leave the client uncertain about the remote outcome. Treating every such error as proof that nothing happened is unsafe. Design a way to look up an operation by its stable business identifier before deciding to submit it again.

Read [retry and idempotency](/learn/sql.retry-and-idempotency) together with [isolation and locks](/learn/sql.isolation-and-locks). A useful review exercise is to list each side effect, the point where it becomes durable, and the evidence available after a timeout. That table usually exposes ambiguous states more clearly than a generic retry helper.

## Measure connection pressure separately from query latency

DB.Stats exposes process-local pool observations. Export the open, in-use and idle counts as gauges. Treat WaitCount and WaitDuration as cumulative values, and calculate changes over the same observation interval. Dividing the change in wait duration by the change in wait count gives an average for waits that were recorded in that interval; it is not a latency percentile and does not describe every request.

Correlate those measurements with arrival rate, completed operations, deadline failures, replica count, transaction duration and database wait events. A rising wait count with consistently saturated in-use connections suggests one investigation. A large idle pool alongside high database execution latency suggests another. Neither proves the final cause without tracing or a controlled reproduction.

The database's own [activity statistics](https://www.postgresql.org/docs/current/monitoring-stats.html) help distinguish active execution, blocked sessions and transactions left open. Keep diagnostics accessible during an outage by preserving the operational connection reserve. Avoid exporting SQL parameter values, raw customer identifiers or unbounded query strings as metric labels.

Create one incident dashboard that shows the whole path. Otherwise the API team may show a timeout chart while the database team shows a fast-query chart, and both charts can be accurate. The purpose of instrumentation is to reconcile those observations into one explanation, not to choose which team appears correct.

## Reproduce the failure you actually care about

A useful test matrix changes one pressure source at a time. Begin with a steady load, then add a short burst. Repeat with a deliberately slow query, a held transaction, an early-abandoned result and a cancelled caller. Finally exercise a rolling deployment so that old and new processes briefly share the database budget. Record the exact schema, dataset scale, driver version and configuration.

Measure useful completions and failures as well as response latency. A system can make a percentile look better by rejecting most requests, or make success rate look better by letting a queue grow until memory becomes the failure mechanism. State the service objective and the acceptable rejection policy before comparing configurations.

For cancellation and rollback tests, verify database state after the request returns. For lock tests, use barriers or explicit transactions to establish the intended ordering rather than hoping that two concurrent clients overlap. For pool-wait tests, a small synthetic driver can validate local ownership behavior, but it cannot replace a PostgreSQL integration environment.

Run these exercises against disposable data. A load generator aimed at production without an agreed budget can create the very incident it is meant to investigate. The examples accompanying this article are small local regression checks, not a measured capacity recommendation for your deployment.

## Turn the investigation into a maintainable contract

The final artifact should be more useful than a larger number in a configuration file. Keep the capacity worksheet, one bounded result-reading example, the transaction owner, cancellation expectations, retry classification and a reproducible test scenario beside the service. Give every resource a documented owner and every queue a reason to exist.

When reviewing a change, ask what happens during a rollout, when the caller leaves, when a result is abandoned and when a commit acknowledgement disappears. These questions connect code structure to operational behavior. They also make strong interview preparation because they require explaining a concrete invariant rather than reciting pool method names.

Continue with [SQL interview scenarios](/interview/http.sql), [bounded concurrency](/learn/concurrency.bounded-work) and [HTTP connection ownership](/news/go-1-27-http-connection-reuse). The same discipline appears in all three: define a budget, acquire deliberately, release reliably, and measure where time was spent. A well-tuned pool is one part of that contract. It cannot compensate for an unbounded queue, a leaked result or an undefined retry outcome.

[Download the original compilable examples and tests](/downloads/go-engineering-examples-20261029.zip). The ZIP includes imports, the local regression suite and a README explaining exactly what was verified.
