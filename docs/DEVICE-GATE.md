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

Measured on an M-series Mac, Go 1.27.1, WasmKit 0.3.1 interpreter:

| | |
| --- | --- |
| `compile.wasm` | 50.9 MB — 7.1 MB compressed |
| `link.wasm` | 11.9 MB — 2.4 MB compressed |
| `vet.wasm` / `gofmt.wasm` | 14.5 MB / 4.8 MB — 2.7 MB / 1.0 MB compressed |
| standard library export data | 138.2 MB, 370 packages — 21.5 MB compressed |
| whole staged artifact | 220 MB |

Bigger than the Go 1.24.2 artifact these numbers replaced, in every row. Three
Go releases of compiler and standard-library growth, and worth knowing before
the device gate rather than after: the compressed total is what an App Store
download carries.

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
7. **A runaway program.** `for { fmt.Println("x") }` must stop being kept after
   1 MiB, report that it was truncated, and leave the device's storage where it
   was. `for {}` will *not* stop — that is a known and documented limit, not a
   test failure — so what is being measured here is what it costs: whether the
   app stays responsive, whether anything is lost, and how the device behaves
   thermally until the app is closed.
8. **An allocation bomb.** A program growing memory without bound is refused at
   64 MiB rather than taking the app down with it.
9. **Repeated unique edits.** Twenty to fifty edit-and-run cycles, each with
   different source, so every one is a cache miss. Memory must not climb with
   the count — the parsed-module cache holds eight — and the on-disk cache must
   stay under its 128 MiB budget.
10. **Low storage.** With the device nearly full, a build fails in a way that
    says so rather than corrupting the library.
11. **Backgrounding mid-edit.** Type, background the app, force-quit it, and
    relaunch: the edit is there. This is the autosave path, and the Simulator
    proves the logic while only a device proves the timing.

## The devices that have to be in it

Not one modern phone. Three profiles, because each answers something the others
cannot:

| Profile | Why |
| --- | --- |
| The oldest hardware the deployment target admits | `iOS 18.0` is the declared minimum, so the App Store will offer this app to hardware several generations old. A local compiler in an interpreter is the worst possible workload for it. |
| A current iPhone | The ordinary case, and the one most reviews will come from. |
| An iPad | A different layout — sidebar, editor and dock at once — and probably the main way this app gets used seriously. |

**The minimum-OS decision belongs to this measurement.** If the oldest
supported hardware throttles, gets killed by jetsam, or takes long enough that
the Build button reads as broken, raising the deployment target is better than
collecting one-star reviews from devices that are formally supported and
practically unsuitable. There is no installed base yet, which makes this the
cheapest moment there will ever be to raise it.

## What a Simulator run can and cannot show

It can show that the integration path works: that the module loads, that WASI
plumbing is correct, that diagnostics parse, that the cache is hit.

It cannot show airplane-mode behaviour, thermal behaviour, memory pressure on
a real device, or interruption under a real scheduler. Those are exactly the
items above that are marked device-only, and they are the ones that decide
whether the product is usable rather than merely demonstrable.
