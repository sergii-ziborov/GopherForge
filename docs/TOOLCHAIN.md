# The bundled toolchain

GopherForge compiles Go on the device, offline, with a real Go compiler. This
is how, and — more usefully — why it is arranged this way rather than the
obvious way.

## The one thing that does not work

The obvious design is to bundle `cmd/go` and shell out to it. That design
cannot work, and no amount of effort makes it work.

`cmd/go` is not a compiler. It is a build orchestrator: it decides which
packages to build in which order, then **spawns `compile` and `link` as child
processes** for each one. WASI has no process creation. There is no
`posix_spawn`, no `fork`, no `exec`, and no plan to add them to the preview-1
API this app targets. A `cmd/go` hosted under WASI can parse your flags and
read your `go.mod`, and then it has nowhere to go.

Every workaround for that is a fork of Go: rewire the build driver to call the
compiler in-process, keep the fork rebased across releases, and own the result
forever. Item 7 of Gate A (`docs/DEVICE-GATE.md`) exists precisely to ask
whether that fork would be small enough to live with.

## What works instead

Skip `cmd/go`. Bundle the tools it would have spawned, and do the ordering in
the app.

    GOOS=wasip1 GOARCH=wasm go build -o compile.wasm cmd/compile
    GOOS=wasip1 GOARCH=wasm go build -o link.wasm    cmd/link
    GOOS=wasip1 GOARCH=wasm go build -o vet.wasm     cmd/vet
    GOOS=wasip1 GOARCH=wasm go build -o gofmt.wasm   cmd/gofmt

All four cross-compile from a stock Go release and run under WasmKit. **The
patch count against upstream Go is zero.** A new Go release is a re-run of
`scripts/build_toolchain.sh`, not a rebase — which is the answer to Gate A item
7, and a considerably better answer than the gate was written to expect.

The cost is that the app now owns the job `cmd/go` was doing. That work lives
in `GopherForge/Compiler/Planning` and it is not large, because the projects
this app builds are not large:

| Type | What it does |
| --- | --- |
| `GoSourceHeader` | Reads the package clause and imports from one file. Only the header, because Go requires every import to precede every declaration. |
| `GoPackageGraph` | Groups files into packages by directory, resolves imports against the module and the bundled standard library, orders dependencies first, and reports a cycle rather than breaking one. |
| `GoBuildPlanner` | Turns a graph and a phase into an ordered list of `compile`/`link`/`vet`/`gofmt` invocations, in guest paths. |
| `GoTestFunctionScanner`, `GoTestMainGenerator` | Find `TestXxx`/`BenchmarkXxx`/`ExampleXxx`/`FuzzXxx` and write the `_testmain.go` that turns a package into a test binary — the same file `go test` generates, including how a custom `TestMain` takes over. |
| `GoVetConfiguration` | The unit-check JSON `cmd/vet` requires. `vet` refuses to be handed source files; `go vet` hands it this instead, and so do we. |
| `GoBuildConstraint` | Decides which files are in the build: `//go:build`, the older `// +build`, and the `_GOOS`/`_GOARCH` filename rules. Without it a package that ships two mutually exclusive implementations compiles both, and every symbol in it is declared twice. |
| `GoPlanFailureReader` | Says why a project could not be planned, in a sentence, because these failures happen before any tool runs and so have no compiler message to show. |

A plan is data. It names a tool, an argv and the files that must exist in the
sandbox before the step runs — nothing else — so the whole build strategy is
something a unit test reads and asserts on rather than something only a device
can prove.

## What ships

`scripts/build_toolchain.sh` produces, in about fifteen seconds:

    compile.wasm             38 MB     5.8 MB compressed
    link.wasm                10 MB     2.0 MB
    vet.wasm                 12 MB     2.5 MB
    gofmt.wasm              4.5 MB     1.0 MB
    goroot/pkg/wasip1_wasm  114 MB    17.7 MB    333 packages of export data

The standard library ships as export data — one `.a` per package, cut from the
same release as the tools — so building a program only ever compiles the user's
own packages and links. `std` deliberately excludes the test-only packages, so
`testing/internal/testdeps` and `testing/quick` are asked for by name; without
them no test binary links.

Nothing here is committed. It is build output from an unpatched release, which
makes it something to reproduce rather than something to store.

## Sandbox

Both the toolchain and the programs it builds are ordinary WASI programs and
run through the same runner, differing only in argv, preopened directories and
limits.

Guest paths are fixed: `/work` (the staged project), `/goroot`, `/cache`,
`/tmp`. Intermediate names are flattened — `example.com/a/b` becomes
`example-com_a_b.a` — so no step ever has to create a directory inside the
guest, where a missing parent would fail a build for a reason that has nothing
to do with the user's code.

Two things about driving these tools directly are worth writing down, because
both cost real time and neither is documented anywhere obvious.

**`cmd/compile` and `cmd/link` print their errors on stdout.** Not stderr.
`go build` relays them to stderr, which is why nobody notices. Reading the
wrong stream means a build that fails with a perfectly good `declared and not
used` in hand and no diagnostics to show for it.

**Build tags are not optional.** `go-cmp` ships `debug_enable.go` and
`debug_disable.go`, guarded by `//go:build cmp_debug` and its negation, and so
does much of the standard library. A planner that compiles every `.go` file in
a directory compiles both and redeclares every symbol. The same pass also has
to know that `unsafe` is resolvable but has no archive: it is a name the
compiler understands, not a library, and pointing an import configuration at a
file that does not exist fails the build.

**The entry point is compiled as `main`, not under its import path.** The
linker resolves `main.main` by package path, so compiling the entry point with
`-p example.com/forge` yields `function main is undeclared in the main
package`. In a *test* binary the rule inverts: the entry point is the generated
test main, so the package under test keeps its own import path even when it is
`package main` — otherwise the generated main could not import it.

The limits are not decorative either, and one of them cost an afternoon.
`cmd/compile` declares just over 20,000 function-table entries, five times what
a user program is allowed. Handing the toolchain the user-program limit denied the
table at instantiation, and the guest then exited without writing a word — a
build that failed for a reason nothing on screen could explain. The toolchain
now has its own table limit, and a denial is written into the step's output
rather than swallowed.

## Where this leaves the gates

Gate A is closed. From a clean checkout on a Mac:

1. `scripts/build_toolchain.sh` produces the artifact — **yes**, in ~15s;
2. `scripts/fetch_toolchain.sh` stages it, or builds it if none exists — **yes**;
3. `hello.go` compiles and runs — **yes**, ~1.4s compile, ~1.4s link;
4. a two-package module compiles and runs — **yes**;
5. `go test` reports per-case results, including a deliberate failure at the
   right file and line — **yes**;
6. an unchanged second run is faster — through the artifact cache, **yes**;
7. the patch set rebases on a Go release — **there is no patch set**.

Gate B still needs a physical device, and nothing here substitutes for it. See
`docs/DEVICE-GATE.md`.
