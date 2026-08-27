# Device gate

What can only be claimed from a physical iPhone or iPad, and what has to happen
before any of it can be attempted.

## Gate A — the toolchain exists at all — CLOSED 2026-08-27

This was the open gate, and it is now shut. The full account is in
`docs/TOOLCHAIN.md`; the short version is that it needed no patched Go.

The gate was written expecting a fork. It asked whether hosting the Go
toolchain in WebAssembly would need a deep, long-lived fork across the
compiler, linker and runtime, and said that if it did, the product stays
possible but stops being a small-team product.

It does not. `cmd/compile`, `cmd/link`, `cmd/vet` and `cmd/gofmt` all
cross-compile to `wasip1/wasm` from a stock Go release with **no patches at
all**, and all four run under WasmKit. What cannot work is `cmd/go`: it builds
by spawning those tools as child processes, and WASI has no way to spawn
anything. So the app does not bundle `cmd/go`. It works out the package order
itself — `GopherForge/Compiler/Planning` — and calls the tools directly.

That trade is the whole result. The app takes on the ordering, the import
configurations and the generated test main, and in exchange a new Go release is
a re-run of `scripts/build_toolchain.sh` rather than a rebase.

Measured on an M-series Mac, Go 1.24.2, WasmKit 0.3.1 interpreter:

| | |
| --- | --- |
| build the artifact | ~15 s |
| `compile.wasm` / `link.wasm` | 38 MB / 10 MB — 5.8 MB / 2.0 MB compressed |
| standard library export data | 114 MB, 333 packages — 17.7 MB compressed |
| hello-world compile | ~1.4 s |
| hello-world link | ~1.4 s |

The seven items the gate asked for:

1. a pinned artifact builds `compile.wasm`, `link.wasm` and a matching
   `goroot/` — **yes**, `scripts/build_toolchain.sh`;
2. `scripts/fetch_toolchain.sh` stages it, verified by SHA-256, or builds one
   when none exists — **yes**;
3. `hello.go` compiles and runs in the Simulator — **yes**;
4. a two-package module inside one `go.mod` compiles and runs — **yes**;
5. `go test` reports per-case results — **yes**, including a deliberate failure
   at the right file and line;
6. an unchanged second run is substantially faster — **yes**, through the
   artifact cache;
7. the patch set against upstream Go is small enough to rebase on a release —
   **there is no patch set**.

Every one of these is covered by `BundledCompilerGateTests`, which runs under
the `GopherForgeCompilerGate` scheme. A missing toolchain fails those tests
rather than skipping them: "we could not check" and "it works" must never look
the same.

## Gate B — the physical device

Only a real device can answer these, and a Simulator run must never be
presented as if it had.

1. **Airplane mode before launch.** Not "network unused" — actually offline,
   enabled before the app starts, for the whole session.
2. **Reported toolchain.** The Build banner names the bundled Go version, and
   Settings shows the size of `compile.wasm` and `link.wasm`.
3. **A real diagnostic.** An unused variable produces `declared and not used`
   at the correct line and column, and the editor marks that line.
4. **A real run.** The repaired program compiles and prints its output.
5. **A real test.** A table-driven `_test.go` runs and reports per-case
   results, including a deliberate failure.
6. **Thermal and memory envelope.** Repeated builds do not push the device into
   throttling or termination. Record the state before and after.
7. **Stop.** A non-terminating program can be stopped, and the app does not
   leave runaway work behind or start a second job on top of a draining one.

## What a Simulator run can and cannot show

It can show that the integration path works: that the module loads, that WASI
plumbing is correct, that diagnostics parse, that the cache is hit.

It cannot show airplane-mode behaviour, thermal behaviour, memory pressure on
a real device, or interruption under a real scheduler. Those are exactly the
items above that are marked device-only, and they are the ones that decide
whether the product is usable rather than merely demonstrable.
