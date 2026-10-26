# Go backpressure: runnable companion

Companion to [Go backpressure: bound concurrency, queues and request deadlines](https://gopherforge.app/news/go-backpressure-concurrency-limits-queues-deadlines).

Requires Go 1.24 or newer; no third-party dependencies. Verified with Go 1.24.2.

```sh
go test -race ./...
go run ./cmd/demo
```

The local demo listens on `127.0.0.1:8080`. In another terminal:

```sh
curl --fail-with-body 'http://127.0.0.1:8080/quote?id=demo'
seq 1 80 | xargs -P 40 -I '{}' curl --silent --show-error \
  --max-time 2 --output /dev/null --write-out '%{http_code}\n' \
  'http://127.0.0.1:8080/quote?id=demo'
```

The demonstration lookup cooperatively waits 80 ms. Sixteen protected requests may execute together; excess requests receive 503 with `Retry-After: 1`. Exact burst outcomes depend on scheduling. The 300 ms context budget covers handler work, while the server has separate socket timeouts. All capacities are illustrative.

`Limit` must be constructed once and shared. It bounds calls to the protected handler and creates no application waiting queue. It does not bound every connection, edge queue, request-body allocation or background task. `WithBudget` requests cooperative cancellation; it cannot forcibly stop arbitrary code or undo completed effects.

`QuoteHandler` validates a GET identifier of 1–64 bytes. The injected lookup owns its dependency protocol. Production adapters need authentication as appropriate, classified error logging, response-write error handling, dependency and body-size budgets, and an explicit policy for ambiguous writes.

Tests check overload refusal, recovery after cancellation and joining, the active-work bound, validation, cooperative timeout, and preservation of an earlier parent deadline. They do not claim a throughput result.
