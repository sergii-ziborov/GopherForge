# Go synchronization and retry lab

Original examples for the GopherForge **5 October** synchronization guide and **11 October** retry/idempotency guide. Actual research and publication date: **29 October 2026**. Archive editions are distinct from publication dates.

## Run

Recorded compiler: **Go 1.27.3, darwin/arm64**. The module declares Go 1.25. All programs and tests use standard-library packages, in-memory state and explicit coordination. No external application, API credential, database, network listener or downloaded third-party module is required.

```sh
go version
go test -race -count=50 ./...
go vet ./...
go run ./invariants
go run ./retrykey
```

Prefix Go commands with `GOTOOLCHAIN=go1.27.3` to select the recorded compiler; first use may download the official Go toolchain.

## Synchronization contracts

- `LostUpdate` deliberately composes separately locked reads and writes. A channel barrier forces both reads to observe zero, so two attempted increments yield one. This is a logical lost update without an unsynchronized shared-memory access.
- `Add` protects the complete transition. Reservation checks and subtraction also share one lock. Tests cover exact capacity, invalid requests, over-capacity requests and concurrent callers.
- `ConfigStore` serializes writers, copies the old map, applies a patch and publishes a completed version with an atomic pointer. Published versions are never mutated.
- `Snapshot` loads one version and returns independent outer-map storage. Values are integers; this is not a recursively deep-copying API for arbitrary values.
- Callers must not mutate an input patch while `Update` reads it. Synchronization objects must retain their identity rather than be copied after use.
- These are semantic examples, not speed rankings for Mutex, RWMutex, sync.Map or atomic operations.

## Retry contracts

- A simulated reply can disappear **after** `Execute` commits both the local effect and its receipt. The caller's unknown observation differs from the store's committed state.
- The same key and typed request replay the original receipt ID and total, with separate replay metadata. Changed valid input under the same key conflicts without changing state.
- A new key declares another operation. The original receipt remains historical even after later work changes the current total.
- The store admits at most 64 records and one million total units. These are arbitrary lab bounds, not production recommendations. Existing matching receipts can replay at capacity.
- The mutex protects one process only. The ledger has no persistence, expiry, authentication, database isolation or external-effect transaction. It does not promise crash recovery or global exactly-once execution.

## Playground

Save/download your existing draft first. Copy either directory's complete `main.go` into the Playground editor's `main.go`, keeping a compatible `go.mod`. Editing does not execute Go or create a room.

If you choose to collaborate, deliberately create a temporary room, open it in a compatible GopherForge native app and press **Run on that device**. Source and device-attributed output are shared through the relay. Native availability, capabilities and expiry are described in the website's MCP guide. AI edits do not automatically run code.

Every Run starts a fresh demonstration. In the retry example, all attempts share one Store **inside a single main invocation**. Repeated app runs do not recover that in-memory ledger.

Try one input change at a time: complete Add versus separate Load/Store; exact versus excessive reservation; caller-owned snapshot mutation; same key/same request versus changed input or a new key. Predict the result before running.

## Validation evidence

The correct suite passed `go test -race -count=50 ./...` and `go vet ./...`. Four temporary broken variants failed their intended tests: rejecting exact capacity, exposing the snapshot's internal map, accepting changed input under an existing key, and omitting receipt insertion. Correct source only is included; negative-control outcomes are recorded separately.

Both standalone programs cross-compiled for `GOOS=wasip1 GOARCH=wasm`. This checks target compilation, not every Wasm host or native app runtime. No production latency, throughput, durable-database or external-provider certification is claimed.
