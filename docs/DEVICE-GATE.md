# Device gate

What can only be claimed from a physical iPhone or iPad, and what has to happen
before any of it can be attempted.

## Gate A — the toolchain exists at all

This is the open gate, and it is upstream of everything else here.

The Rust sibling could point at a published WASI build of `rustc`. Go has no
equivalent: the toolchain has been hosted in WebAssembly before — the archived
Static Go Playground did it for the Go 1.13–1.18 era — but that work targeted a
browser and is years behind current Go.

This product needs something narrower and, in one respect, easier:

- `GOOS=wasip1` rather than `js/wasm`, because the app runs guest code under
  WASI in WasmKit and has no JavaScript engine. Go has supported wasip1 as a
  first-class port since 1.21;
- the toolchain driver itself hosted as a wasip1 program, which is the part the
  upstream project does not support as a normal configuration;
- a bundled GOROOT with the standard library, and a build cache that survives
  between runs.

Gate A passes when, from a clean checkout on a Mac:

1. a pinned artifact builds `gotool.wasm` and a matching `goroot/`;
2. `scripts/fetch_toolchain.sh` stages it, verified by SHA-256;
3. `hello.go` compiles and runs in the Simulator;
4. a two-package module inside one `go.mod` compiles and runs;
5. `go test` reports per-case results;
6. the build cache makes an unchanged second run substantially faster;
7. the patch set against upstream Go is small enough to rebase on a release.

If item 7 fails — if this needs a deep, long-lived fork across the compiler,
linker and runtime — the product is still possible but stops being a
small-team product. That is a re-scoring decision, not an engineering detail,
and it should be taken explicitly.

## Gate B — the physical device

Only a real device can answer these, and a Simulator run must never be
presented as if it had.

1. **Airplane mode before launch.** Not "network unused" — actually offline,
   enabled before the app starts, for the whole session.
2. **Reported toolchain.** The Build banner names `gotool.wasm` and its Go
   version, and Settings shows the driver size.
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
