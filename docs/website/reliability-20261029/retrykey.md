## A timeout describes the caller's observation

A document-conversion request reaches a service, reserves seven processing units and commits a result. The response disappears before the client receives it. The client sees a timeout or connection error. Did the work fail? From that observation alone, the client may not know. Repeating the operation with a fresh identity can apply the effect again even though the first attempt completed successfully.

This guide separates retry policy from duplicate-effect prevention. A retry decides whether and when to make another attempt. An idempotency contract decides which attempts represent the same logical operation and how the service recognizes their outcome. Backoff can reduce pressure, but it cannot recognize an already committed operation by itself.

The downloadable Go lab makes the lost-response window explicit without a real network. One function commits an in-memory effect and receipt, then deliberately drops the returned reply. The next call uses the same key. The example is original, bounded and reproducible; it is not a durable database, a payment integration or a universal exactly-once execution mechanism.

## Distinguish failure before work from an unknown outcome

Different failure points require different decisions. A rejected input may never enter the business operation. A client may abandon a call while the service continues. A database commit may succeed while the reply is lost. A remote dependency may perform its effect before the local service manages to record that fact.

| Evidence available | What can be concluded | Useful next action |
| --- | --- | --- |
| Definitive validation rejection before admission | This operation was not accepted | Correct the input |
| Caller deadline elapsed | Caller stopped waiting | Preserve identity; inspect the operation contract |
| Stored committed receipt for the same key | The recorded operation completed | Return or reconcile that result |
| External effect with missing local record | Local evidence is incomplete | Reconcile with the external owner |

The [HTTP semantics specification](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2) defines method idempotency, but an application still needs to understand its actual operation. A response status or a transport exception is not a complete transaction log. Do not infer that no business effect occurred merely because the client did not receive a successful response.

In particular, unknown is often the caller's knowledge state, not a special row that every service stores. The lab's service knows it committed; its simulated caller has lost the response. Keeping those viewpoints separate makes reconciliation much easier to explain.

## Give the logical operation a stable identity

The client should preserve the same operation key across attempts that are intended to represent one action. Generating a new key after every timeout declares a different operation to a service whose contract uses that key for deduplication. The second request may then be entirely valid and still produce the duplicate effect the client wanted to avoid.

Our toy request contains a job name and a positive unit count. The store compares those typed fields when a key already exists. A matching request receives the original receipt identifier and committed total, with separate replay metadata. A valid but different job name or unit count produces a conflict and does not change state.

```go
if old, ok := s.records[key]; ok {
    if old.request != req {
        return Receipt{}, ErrConflict
    }
    replay := old.receipt
    replay.Replayed = true
    return replay, nil
}
```

Choose the identity scope deliberately in a real API. An operation name, API version and authorized caller scope may be part of the contract. An idempotency key is not authentication or permission to retrieve somebody else's result. Avoid putting secrets or personal information into keys just to make them recognizable in logs.

The [Stripe idempotency documentation](https://docs.stripe.com/api/idempotent_requests) is a concrete provider example and distinguishes API-version behavior. Read the selected provider's actual replay, conflict and retention rules instead of assuming that every API implements this lab's contract.

## Record the effect and receipt under one boundary

If the business effect can commit without the deduplication record, a retry may see no record and apply the effect again. If a completed-looking receipt can be stored before the effect is actually committed, a retry may incorrectly report success. The relationship between those two records is the core invariant.

In the lab, one mutex protects the total, lookup and receipt insertion. Both the effect and its receipt exist in the same process memory and are changed within one local critical section. This makes the example's concurrency behavior easy to test, while leaving durability explicitly outside its claim.

```go
s.total += req.Units
res := Receipt{ID: len(s.records) + 1, Total: s.total}
s.records[key] = record{request: req, receipt: res}
return res, nil
```

For a database-backed service, put the relevant local business change and idempotency result inside an appropriate database transaction. The [Go transaction guide](https://go.dev/doc/database/execute-transactions) explains using a transaction object for the operations that belong to it. Mixing unrelated pool calls into the workflow can accidentally move work outside the intended transaction.

The companion [synchronization guide](/news/go-concurrency-invariants-mutex-atomic-snapshots) illustrates the same mistake at a smaller scale: individually safe reads and writes do not automatically make their composition one atomic operation. Here the missing boundary can survive a client timeout and become a duplicate business effect.

## Use durable uniqueness and test the chosen isolation behavior

A local mutex coordinates goroutines in one process. Two service instances do not share it. A deployment with several replicas needs a shared authority for operation identity if requests can reach different instances. A check in application memory followed by an insert is not a substitute for a durable uniqueness rule.

The [PostgreSQL constraint reference](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS) describes uniqueness constraints. The exact key should reflect the API's identity scope. The [transaction-isolation reference](https://www.postgresql.org/docs/current/transaction-iso.html) explains why concurrent transaction behavior depends on the selected isolation level and operations. A production implementation must handle conflicts, waiting and serialization failures under that actual model.

Do not copy a fragment of SQL and assume it resolves every concurrent conflict. Test two real connections presenting the same key, the same key with changed input, a rollback before commit, and a connection failure around commit. Verify both the stored effect and the response returned by the retry.

The in-memory lab does not perform those database tests or certify a particular driver. It teaches the invariant that the durable implementation must preserve. The earlier [database/sql guide](/news/go-database-sql-pool-timeouts-transactions) covers transaction ownership, pool limits and deadlines that remain relevant while duplicate requests wait for an outcome.

## Replay a historical receipt without pretending it is current state

An idempotency result can describe what happened when the original operation committed. It need not be a fresh query of all current application state. The lab makes that distinction visible: operation one records a total of seven; another separately identified operation later raises the current total to fourteen. Replaying operation one still returns its original total of seven.

That result is consistent with the declared receipt contract. Treating it as the current total would be a client modeling error. Name fields and endpoints so callers can distinguish a historical operation result from a live resource read. If the API instead promises an updated representation on replay, document and test that different behavior.

Likewise, decide which delivery metadata is separate from the business result. Our Replayed flag changes to describe how the reply was obtained; its operation identifier and committed total remain the recorded values. We do not claim byte-for-byte identical response bodies for this toy API.

Persist enough information to honor the response contract through a deployment. A code update that can no longer decode older result records may break retries for operations that are still within their supported replay window. Include result schema evolution in the design rather than treating stored responses as an incidental cache that can be discarded without changing behavior.

## Define what concurrent duplicates should observe

When many callers present the same key simultaneously, a service needs a policy for the in-progress operation. It may wait within a deadline, return a pending response with a lookup path, or reject an overlapping attempt according to its API contract. What matters is that duplicate callers do not independently perform the same unprotected effect.

The lab serializes calls inside the local mutex. Its concurrent test starts sixty-four callers with one key and verifies one effect, one original receipt and consistent replayed business results. That is a local result for the included implementation, not evidence that an external service or a multi-replica deployment has the same behavior.

The [singleflight package](https://pkg.go.dev/golang.org/x/sync/singleflight) addresses duplicate in-flight function calls in one process. It solves a different problem from durable idempotency. Suppressing overlapping work does not by itself preserve a result after restart or prevent a later repeated request from applying an effect again.

If the durable design stores a pending state, define who owns it and how another worker decides whether it may take over. An expired lease does not prove the previous worker has stopped or that its external effect did not happen. The [coordination lesson](/learn/datastores.redis-coordination) helps connect ownership, conditional transitions and the limits of a simple expiry timestamp.

## A local transaction does not cover a separate external effect

A service may commit local state and then publish a message, invoke another API or write to another independent system. There is a failure window between those operations unless the architecture supplies a protocol that covers it. A local idempotency row cannot magically make all remote work part of its transaction.

The [transactional outbox guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) describes recording outgoing work with a local database change so a separate delivery process can retry it. The receiving side still needs an appropriate duplicate-handling contract. Delivery retries and consumer effects belong to related but separate boundaries.

For the document service, a local accepted job and its outgoing event might be recorded together. A dispatcher can resend the event after a failure. The consumer identifies the intended operation and avoids creating another conversion for the same event identity. The design should explain when work is acknowledged and how an operator can reconcile a persistent uncertain outcome.

These are architectural recommendations, not capabilities secretly implemented by the small Store example. It has no database, queue, remote API or durable recovery. Follow the [event-driven architecture lesson](/learn/architecture.event-driven) and [SQL retry lesson](/learn/sql.retry-and-idempotency) when translating the local invariant into a real workflow with more than one failure domain.

## Keep retry policy bounded and owned by one layer

Even a correctly idempotent effect can be expensive to look up, validate or wait for. Retrying indefinitely can increase load precisely when a dependency is least able to recover. The [AWS retry guidance](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) explains the role of timeouts, backoff and jitter in controlling that pressure.

Choose an overall operation budget, a finite attempt policy and a definition of retryable failures. Keep the same logical identity throughout those attempts. If several nested layers each retry independently, the number of downstream calls can grow far beyond the caller's intended allowance. Decide which layer owns retries and expose enough information for the other layers to avoid repeating the policy accidentally.

The [context package](https://pkg.go.dev/context) provides deadline and cancellation propagation within Go calls. A child attempt should respect the remaining parent allowance. Waiting before the next attempt must also be cancellable. A caller's expired budget should not silently reset to a full new budget at every helper boundary.

Use [bounded work](/news/go-backpressure-concurrency-limits-queues-deadlines), the [retry-pattern lesson](/learn/patterns.retry) and [time budgets](/news/go-time-utc-dst-monotonic-deadlines) together. Backoff chooses when to try; idempotency preserves operation identity; admission control decides whether the system can accept more work. None of those responsibilities disappears because the others are present.

## Make retention and capacity part of the contract

A deduplication record cannot recognize a retry after it has been forgotten. Expiring records therefore changes the period during which the API can honor a particular replay promise. Choose that period from the operation's retry and delivery horizon, including delayed clients or redeliveries that the system is expected to support.

Our lab deliberately caps its ledger at sixty-four records and its total units at one million. These are demonstration boundaries, not recommended production settings. A new operation beyond capacity is rejected; an already stored matching request can still replay. The test checks lookup before the new-operation capacity check so saturation does not unnecessarily block an existing receipt.

A production service needs a storage, cleanup and rejection policy that preserves its documented semantics. Deleting the oldest record whenever memory becomes inconvenient can make a delayed duplicate look like a new operation. Keeping everything indefinitely can create an unbounded resource problem. The tradeoff must be explicit and observable.

Record decisions about key reuse, operation duration and result availability. If clients are allowed to retry after process restart, the client must preserve its operation identity and the server must retain the relevant durable evidence. A temporary local variable or a one-hour collaboration room is not a durable business-operation ledger.

## Reproduce the lost reply in Playground

[Download the synchronization and retry lab](/downloads/go-reliability-lab-20261029.zip) and inspect retrykey/main.go. Before replacing an existing [Playground](/playground) draft, download your source copy. Paste the self-contained program into main.go and keep a compatible go.mod. The example uses standard-library packages and in-memory state, with no remote requests or credentials.

All attempts in this demonstration occur inside one invocation of main. Each new Run constructs a fresh Store; it does not recover a ledger from an earlier run. This is important when interpreting the result. The example demonstrates a lost response after a local commit and replay within that store's lifetime, not durable recovery across app launches.

Predict the result, run once, then change one input. Reuse the same key and request: the effect remains seven. Change the valid unit count under the same key: the request conflicts. Change to a new key: it declares another operation and the current total becomes fourteen. Compare the historical receipt with the current total after that second operation.

To collaborate, create a temporary room deliberately, open it in a compatible GopherForge app and press Run on the device that should execute. Other participants receive device-labelled output for that source revision. Claude or Codex can suggest a mutation through MCP, but editing does not start execution. The [MCP guide](/guide/mcp) explains the link capabilities and expiry; reading this article does not create or publish a room.

## Test the failure window, not only the success response

The suite verifies the effect and receipt immediately after the simulated reply disappears, then retries using the stable key. It also covers changed input, concurrent duplicates, historical receipts, invalid requests, capacity rejection and replay at capacity. The critical assertions concern stored state and operation identity, not just whether an error message appeared.

```sh
go test -race -count=50 ./...
go vet ./...
go run ./retrykey
```

Negative variants remove the changed-input check or omit receipt insertion. Their tests must fail: a mismatched request cannot silently receive another operation's result, and an unrecorded committed effect cannot be replayed safely. The complete native suite was checked with Go 1.27.3; the standalone programs also cross-compile for wasip1/wasm. That target build is separate from certifying every runtime host or a production distributed system.

For the real service, extend the matrix across process termination, database commit, message delivery and external effects. Decide which evidence survives each failure and which owner can reconcile it. A useful retry design does not promise that nothing can ever happen twice. It specifies one logical identity, the boundary protecting its effect and receipt, the period those records remain authoritative, and the action a caller should take when its observation is incomplete.
