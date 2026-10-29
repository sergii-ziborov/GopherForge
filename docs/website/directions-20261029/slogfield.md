## A log event is an interface that someone will depend on

A useful diagnostic event answers a specific operational question without exposing everything the application knows. For a request-completion event, the question might be: which operation finished, with what result, and how long did its application work take? Dumping a request object is an easy implementation and a poor contract. It mixes useful fields with unstable structure, secrets and accidental identifiers.

This is our **10 October archive guide**, researched and first published on **29 October 2026**. We selected the topic after checking related Google Trends queries, where `golang slog` appeared as a rising query, then verified that our article library lacked a deep treatment. That observation helped select a useful topic; it does not prove production adoption or make this an announcement of a new Go package.

Go introduced `log/slog` in Go 1.21. It provides structured events and separates the logger frontend from handlers that process them. The original [Go announcement](https://go.dev/blog/slog) explains that architecture. Here we use it to investigate a narrower question: can our event schema remain useful when requests fail, values contain secrets, debug output is disabled and the destination refuses writes?

## Define the event before choosing the output format

Imagine a catalog API. Its completion event has a stable name, a service label, a synthetic request identifier and a grouped set of operation fields. The route is a trusted template such as `/items/{id}`. It is not the incoming path. Status and elapsed milliseconds are numbers, while the outcome belongs to a small documented set.

| Field | Example | Ownership rule |
| --- | --- | --- |
| `msg` | `request.complete` | Stable event name, never an interpolated payload |
| `service` | `catalog` | Fixed deployment/application label |
| `request_id` | `demo-001` | Synthetic lab ID; production policy must be explicit |
| `request.route` | `/items/{id}` | Trusted route template, not raw URL input |
| `request.status` | `503` | Result recorded by the response owner |
| `request.duration_ms` | `12` | Integer milliseconds with a declared unit |
| `request.outcome` | `deadline` | Deliberate classification, not an arbitrary error message |

This schema is a design for the example, not a mandatory industry standard. Its value comes from making field meaning inspectable. Decide whether duration includes waiting for dependencies and whether it stops before or after writing the response. Decide how an abandoned response is classified. If two services use the same field name for different intervals, a shared dashboard will not repair the ambiguity.

Our [Go directions guide](/news/go-popularity-2026-google-trends-cloud-ai-directions) explains why these operating skills matter beyond framework choice. The same event discipline applies to a CLI job, a queue worker or an AI tool invocation, although each needs its own completion contract.

## Start with a small JSON handler and explicit attributes

The downloadable lab uses only the standard library and synthetic values. It does not add analytics or logging to GopherForge itself. Its logger construction accepts an `io.Writer`, making the output destination replaceable in tests. A deterministic option removes timestamps only for stable lab output; an actual service must deliberately choose its timestamp and retention policies.

```go
func RequestLogger(base *slog.Logger, requestID string) *slog.Logger {
    return base.With(
        slog.String("service", "catalog"),
        slog.String("request_id", requestID),
    ).WithGroup("request")
}
```

The lab then emits typed attributes for route, status, elapsed milliseconds and classified outcome. A successful example produces this JSON object:

```json
{
  "level": "INFO",
  "msg": "request.complete",
  "service": "catalog",
  "request_id": "demo-001",
  "request": {
    "route": "/items/{id}",
    "status": 200,
    "duration_ms": 120,
    "outcome": "ok"
  }
}
```

The duration is a chosen demonstration value, not a benchmark. Tests decode JSON and assert names, grouping, values and absence of unexpected fields. They do not compare whitespace or require a particular object-key order. That makes the test sensitive to a broken event contract while allowing formatting details to change.

The [package reference](https://pkg.go.dev/log/slog) documents JSONHandler, attributes, groups, levels and value resolution. Our tests explore concrete consequences of those APIs rather than requiring a custom handler for a routine event. Start with the built-in handler; introduce another processing layer only when its behavior is necessary and testable.

## Context propagation and event fields are separate decisions

Passing `ctx` into a contextual logging method lets a handler inspect that context. It does not mean every context value becomes a JSON field. In this lab the request ID is attached explicitly with `With`, and the route is supplied explicitly when recording completion. There is no reflective scan of context values and no hidden dependence on a framework request object.

The test cancels its context before logging a synthetic completion. The event still appears. This is useful because cancellation itself can be the event we need to explain. The context's cancellation is not a request to erase diagnostics. A logging implementation should not silently lose the last event merely because application work correctly stopped.

In a Gin service, extract the few approved values at the HTTP boundary and retain their meaning. Do not retain the full framework context in a goroutine or make the logger responsible for deciding whether a response has been sent. Work through [Gin contexts and workers](/learn/gin.context-workers) and [response ownership](/learn/gin.errors-testing) before attaching background diagnostics.

A request-scoped child logger is a convenient carrier of stable fields, but it is still an application dependency. Pass it deliberately where useful. Avoid turning every package into a collection of ambient globals that a test must reconfigure. A function can often return a classified result to its owner and let that owner emit one completion event.

## Redaction begins with what never enters the event

The strongest protection in our example is its small input surface. It never receives headers, bodies, raw URLs or capability links. Removing a query string is insufficient: a secret can live in the path itself. Removing a URL fragment is also insufficient when the application already copied that fragment into another field. Choose a trusted route template instead of trying to sanitize an arbitrary address after capture.

OWASP's [logging guidance](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) recommends excluding sensitive material and testing logging failures. For this lab, we apply that principle through synthetic inputs, an approved schema and two deliberately limited redaction mechanisms. Neither is advertised as a universal personal-data detector.

```go
type Secret string

func (Secret) LogValue() slog.Value {
    return slog.StringValue("[REDACTED]")
}
```

A typed `Secret` passed as a value resolves to a redacted representation. The test also logs `string(Secret("synthetic-plaintext"))` under an ordinary field name and verifies that the plaintext remains. That is an intentional counterexample: conversion discarded the protective behavior. It uses fabricated data and demonstrates why a type cannot prevent callers from copying the original text elsewhere.

The second mechanism replaces explicitly named attributes such as `authorization`, `password` and `token`, case-insensitively, including attributes inside groups. This protects those known names in this output handler. It does not inspect every string, recursively understand arbitrary application objects or repair a message that already contains a secret. Treat it as a defense behind the schema, not permission to log whole objects.

## Error classification should preserve meaning without copying everything

An error can contain a database statement, an address, a remote response or an embedded credential. Blindly recording `err.Error()` therefore expands the event's input surface. Our lab classifies nil, wrapped deadline errors, wrapped cancellation errors and everything else into a small set. Its test supplies an error containing a synthetic private marker and verifies that the marker never appears in the event.

The classification is intentionally coarse. A real application may need stable codes for missing resources, invalid input, dependency failure or an uncertain result. Define those codes at the operation boundary rather than mining arbitrary message text. Keep the original error available to the caller that must decide what to do, and separately decide which diagnostic detail is approved for which destination.

The lab emits ERROR for status codes at or above 500 and INFO otherwise. That is an example policy, not a rule that every cancellation or client mistake is harmless. A shutdown cancellation, a user-aborted read and an internal budget exhaustion have different operational implications. Make the policy coherent with your alerts, and test a small representative matrix instead of assigning severity by whichever helper was easiest to call.

Our [typed error guide](/news/go-typed-nil-errors-as-contracts) and [retry outcomes guide](/news/go-retries-idempotency-keys-unknown-outcomes) provide related failure models. In particular, an unknown external outcome should not be renamed “failed” merely because the caller timed out. A diagnostic field should retain that distinction.

## Disabled debug output can still evaluate expensive arguments

A common surprise is a debug call whose output is disabled but whose argument function still runs. The language evaluates call arguments before entering the called function. The logger cannot undo work the caller already performed. This is ordinary [Go call semantics](https://go.dev/ref/spec#Calls), not a special logging scheduler.

```go
if logger.Enabled(ctx, slog.LevelDebug) {
    logger.DebugContext(ctx, "diagnostic.summary",
        "summary", buildSummary())
}
```

The lab first invokes an eager debug call, then the guarded version while INFO is the minimum level. A counter records one summary construction: the eager expression ran, the guarded one did not. After changing the shared LevelVar to DEBUG, the guarded call builds and emits its summary. This is a semantic test, not evidence of a universal speedup percentage.

Use this guard for genuinely expensive preparation. Do not scatter it around every scalar attribute until readability suffers. A deferred value can be another option, but its ownership and evaluation behavior still need review. Never capture a mutable request buffer in a value that might be processed later without defining who owns that memory.

The lesson extends beyond logging: “disabled” often describes the callee's behavior, while argument evaluation belongs to the caller. The best optimization begins by locating the actual work, then measuring a representative workload after correctness is preserved.

## A successful application operation does not prove log delivery

Our synthetic writer returns zero bytes and a fixed error. Calling the ordinary logger invokes that writer but provides no error result to the application. Calling the handler directly returns the writer failure. The test checks both observations separately. It does not pretend that a successful `Info` call is a durable receipt for a diagnostic event.

The [handler guide](https://github.com/golang/example/tree/master/slog-handler-guide) explains handler implementation and error handling. The [Writer contract](https://pkg.go.dev/io#Writer) explains byte counts and write errors. A destination can fail independently of the work being described. If your operation requires an auditable durable record, design that record's persistence and transaction boundary explicitly; a diagnostic logger is not a substitute for the business ledger.

Avoid reporting a sink failure by recursively invoking the same failed sink. A production design might count failures through a separate mechanism or expose health through another destination, but that mechanism also needs bounds. Decide what the application should do when diagnostics are degraded and test that decision with a failing writer.

The example makes no automatic retry promise. Retrying a log write can duplicate events, delay the caller or consume an unbounded amount of memory. If you add retries, specify maximum attempts, waiting time and duplicate semantics. Those decisions belong to your delivery contract, not to the JSON format.

## Blocking, queues and concurrent callers need explicit boundaries

A slow synchronous destination can delay the goroutine that emits an event. An asynchronous queue can move that delay elsewhere, but it introduces a capacity, an overflow policy and a shutdown obligation. At saturation, will you block, drop, sample or reject new work? A queue with no admission bound converts a slow sink into retained memory.

For an educational experiment, replace the writer with one that signals entry and waits for an explicit release channel. Observe which caller waits, then release it and join the goroutine. Avoid timing guesses such as sleeping for a few milliseconds and declaring that a race has been reproduced. Our [controlled concurrency tests guide](/news/go-concurrency-tests-synctest-without-sleeps) develops that testing approach.

The supplied lab also shares one JSON handler across sixteen workers, waits for all workers, then decodes every event. It checks that records remain parseable and that creating a grouped child did not mutate the root logger. This verifies the chosen handler and setup; it does not certify every custom writer, asynchronous wrapper or log collector as concurrency-safe.

If you write a handler, follow the official handler guide's concurrency and record-ownership requirements. A queue that retains a record must preserve the state it needs and define who may mutate it. Review this beside our [buffer ownership guide](/news/go-bytes-buffer-sync-pool-ownership) and [backpressure guide](/news/go-backpressure-concurrency-limits-queues-deadlines).

## Run the lab and test useful broken variants

Download the [original structured-logging lab and research bundle](/downloads/go-directions-slog-lab-20261029.zip). It includes the complete standalone program, tests, the captured Trends tables, the calculation script and a README distinguishing observations from forecasts. There are no credentials, network listeners, external services or third-party Go modules in the example.

```sh
go version
go test -race -count=50 ./...
go vet ./...
go run ./sloglab
```

Our recorded compiler is Go 1.27.3 on darwin/arm64. Selecting that compiler with `GOTOOLCHAIN` may download the official toolchain on first use. The example also cross-compiles for wasip1/wasm; that establishes target compilation, not successful execution in every host. The native run prints JSON events and the separate argument-count and writer-error observations.

The verification includes temporary negative controls: exposing the typed secret, removing the request group, choosing the wrong failure level and removing the expensive-work guard. Each broken variant must fail its intended test. Otherwise a green test could merely be exercising code without checking its contract. The downloadable source contains only the correct version.

For a [Playground](/playground) exercise, save your current draft before replacing it. Copy the complete `sloglab/main.go`, keeping a compatible module. Editing does not execute code. In a deliberate collaboration room, press Run on the selected compatible native device; the relay carries source and device-attributed output. See the [MCP guide](/guide/mcp) for execution and temporary-link behavior. A browser editor alone is not evidence that a Go program ran.

## A review checklist that improves the next incident investigation

Ask a teammate to explain one event without reading its emitter. Can they distinguish an operation name from an incoming address, identify the duration unit and tell whether an outcome means rejected, canceled, committed or unknown? If the answer depends on tribal knowledge, improve the schema before adding more volume.

Next, test omission. Verify that bodies, authorization headers, raw capability URLs and arbitrary error text never reach the event constructor. Then test the redaction mechanisms with fabricated markers, including the conversion counterexample. An absence check is stronger when the test first proves that the marker would otherwise have been observable.

Finally, disconnect the destination in a controlled environment. Observe what the caller does, whether memory remains bounded and how shutdown completes. Diagnostics should help explain the system while retaining a clear separation from its business guarantees. That separation is what makes structured logging dependable rather than merely structured.
