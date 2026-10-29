# Go memory investigation lab

Original GopherForge examples accompanying the 1, 3 and 13 October archive editions. Written and measured on 29 October 2026; the historical edition labels are not the publication dates.

## Reproduce

Use a native Go toolchain supporting Go 1.25 or later. The recorded run selected **Go 1.27.3, darwin/arm64, Apple M4, GOMAXPROCS=2**. Toolchain version changes can alter compiler diagnostics and observations. These results do not certify production-service latency, process RSS limits or the app's Wasm sandbox.

From the archive's root (containing `go.mod`), or from `examples/` in the repository:

```sh
go version
go test -race -count=10 ./...
go build -o memlab ./cmd/memlab
# Clear inherited collector settings before these isolated comparisons.
unset GOGC GOMEMLIMIT
GOGC=50 ./memlab -mode gc
GOGC=100 ./memlab -mode gc
GOGC=200 ./memlab -mode gc
GOGC=200 GOMEMLIMIT=32MiB ./memlab -mode gc
GOGC=100 ./memlab -mode chain
GOGC=100 ./memlab -mode tree
./memlab -mode view
./memlab -mode clip
./memlab -mode copy
./memlab -mode profile -out heap.pprof
go tool pprof -top -sample_index=alloc_space ./memlab heap.pprof
go tool pprof -top -sample_index=inuse_space ./memlab heap.pprof
GOMAXPROCS=2 go test -run '^$' -bench 'Benchmark(Format|Append)$' -benchmem -benchtime=150ms -count=5
go build -gcflags=-m=2 .
```

To select the same toolchain with Go's toolchain mechanism, prefix Go commands with `GOTOOLCHAIN=go1.27.3`; the first use may download that compiler. The examples themselves use no network access or external dependencies.

## Method and limits

- The GC case holds 12 MiB and churns 512 × 512 KiB. A collection establishes the start boundary; reported cycles concern the allocation loop. The heap goal is sampled at the loop's end, not a peak or a hard cap. Sys minus HeapReleased describes runtime-managed memory, not all process memory.
- Each configuration was run sequentially in three fresh processes. This is an exploratory observation, not a randomized performance study. `research-results.json` preserves each result and medians.
- Chain and tree use 100,000 identical nodes, one root and N−1 non-nil edges. Construction indices and validation work are discarded before measurement. Seven complete forced GC durations are recorded per process. They are not pure mark-phase times. Topology, locality and work distribution change together; no universal timing ratio follows.
- View, capacity-clipped view and independent copy return equal 32-byte payloads from a 16-MiB input. A clipped capacity does not detach backing storage. Small post-GC deltas include runtime and measurement overhead.
- The profile allocates 128 MiB of payload and retains exactly sixteen 64-KiB blocks. Sampling is set to 64 KiB before the workload. pprof numbers are estimates in its printed units, not an exact allocation ledger.
- Formatter benchmarks use one positive identifier and `true`; semantic tests also cover zero, maximum uint64 and both booleans. Both measured implementations report one allocation and 24 B/op. Median timing differs; this is not a whole-service speedup.
- `GraphStats` only walks the acyclic lab graphs; it is not a general cycle-aware traversal. `CopyPrefix` requires a valid prefix length.
- `runtime.GC` and `runtime.KeepAlive` define measurement boundaries here. This is not a recommendation to collect after each request.

## Validation

The final source passed `go test -race -count=10 ./...`. Three temporary deliberately broken variants each failed its intended assertion: independent-copy aliasing, formatter output mismatch, and a missing graph node. Only original correct source is included. The tests check semantics and structure; they do not assert noisy timings or portable byte counts.

Data includes raw benchmark output, compiler diagnostics, sampled profile reports, source hashes, and all 27 isolated configuration results. No third-party application code or binary is included.
