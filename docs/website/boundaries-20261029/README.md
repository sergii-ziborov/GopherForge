# Go input and time boundaries lab

Original GopherForge examples accompanying the **4 October** streaming-I/O and **12 October** time guides. Actual research and publication: **29 October 2026**. These are archive editions, not claims of historical publication.

## Run locally

The recorded toolchain was **Go 1.27.3, darwin/arm64**. `go.mod` requires Go 1.25 because the asynchronous tests use stable `testing/synctest`.

```sh
go version
go test -race -count=50 ./...
go run ./streamio
go run ./gotime
```

To select the same compiler, prefix Go commands with `GOTOOLCHAIN=go1.27.3`; first use may download the official toolchain. Example programs use in-memory data and standard-library packages, without network requests or external modules. HTTP tests use a recorder and a local reader, not a listening server.

## Input lab

- `finalChunk` returns the last bytes together with EOF. It supports small destination buffers, too.
- `ReadBounded` reads at most N+1 bytes, accepts exactly N, rejects overflow, guards invalid limits, and exposes no accepted payload after a transport failure.
- `DecodeOne` first establishes a bounded envelope, then requires one JSON document, no unknown fields, and a nonempty ID. **It is not a duplicate-key rejection implementation**: the fixture explicitly demonstrates the later ID winning.
- Scanner's default buffer fails on the 70-KiB line; a 128-KiB token budget accepts it. Per-token limits are separate from whole-stream and processing budgets.
- Buffered-output tests require an explicit successful flush and preserve a late destination error. Flush alone does not prove remote processing or durable storage.

## Time lab

- Fixed Europe/Zurich noon fixtures span 28–29 March 2026 (23 elapsed hours) and 24–25 October 2026 (25 elapsed hours). `Add(24*time.Hour)` reaches a different local hour.
- `NextDay` is an arithmetic demonstration at unambiguous noon, **not a full scheduler policy** for missing/repeated local clock readings or recurring delivery.
- `time/tzdata` supplies embedded fallback zone data. The selected executable's environment and toolchain still need to be recorded.
- Equal instants can have unequal representations. Two offset strings parse to the same instant; Round(0) preserves instant equality.
- Timer tests use virtual time, cancellation and explicit joining. They make no claim about priority when cancellation and timer readiness race.

## Playground exercise

Save/download your current draft before replacing it. Copy either directory's complete `main.go` into `main.go` in GopherForge Playground; keep a compatible `go.mod`. Reading and editing do not run code or create a room. To collaborate, deliberately create a temporary room, then open it in a compatible GopherForge native app and press **Run on that device**. The relay shares source and device-attributed output. Compatible native availability is described in the site's MCP guide; this download does not add a browser Go runtime.

Try one mutation at a time: N versus N+1 bytes; a second JSON value versus trailing whitespace; a larger Scanner token; fixed-offset location versus a named location; elapsed 24 hours versus a calendar day. Predict before running. An assistant can suggest edits through MCP, but execution remains a local button action.

## Evidence and limits

The complete native suite passed 50 repeated runs with the race detector. Four temporary negative variants failed their intended assertions: truncated oversize input, ignored second JSON document, fixed-duration calendar addition, and missing timer cancellation. Correct sources only are included.

Both standalone programs also cross-compiled for `GOOS=wasip1 GOARCH=wasm`. That checks target compilation; it is not an end-to-end certification of every Wasm host or native app build. No throughput, memory benchmark, network timing, production scheduler or distributed-clock guarantee is claimed.

Raw observed output, test outcomes and source hashes accompany the sources. Assertions target values, types and lifecycle contracts, not unstable error wording. Third-party applications and binary artifacts are not included.
