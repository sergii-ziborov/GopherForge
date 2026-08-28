# Third-party notices

GopherForge is proprietary software. The components below are bundled or linked
under their own licences, which are unaffected by that.

Every licence here permits redistribution provided the copyright notice and
disclaimer travel with the software. Where a component ships as source inside
the app, its own `LICENSE` file travels with it; where it does not, its notice
is reproduced below.

## The Go toolchain and standard library

Copyright © The Go Authors. **BSD 3-Clause License.**

`compile.wasm`, `link.wasm`, `vet.wasm`, `gofmt.wasm` and the staged standard
library are builds of the upstream Go project, cross-compiled to `wasip1/wasm`
with no modifications. Because those are binary redistributions, Go's own
`LICENSE` and `PATENTS` are staged beside them and ship inside the app at
`Toolchain/<version>/goroot/`. `scripts/build_toolchain.sh` refuses to produce
an artifact without them.

<https://go.dev/LICENSE>

The Go gopher was designed by Renée French and is **not** used here.
GopherForge's mark is original artwork.

## WasmKit 0.3.1

Copyright © 2020 Akio Yasui. **MIT License.**

The WebAssembly interpreter that runs both the bundled toolchain and every
program this app builds. WasmKit includes derived code from Swift System and a
derived Swift keyword list from Swift Syntax, both Apache-2.0; see the upstream
`NOTICE.txt` for those attributions.

<https://github.com/swiftwasm/WasmKit/tree/0.3.1>

## swift-system 1.8.1

Copyright © Apple Inc. and the Swift System project authors.
**Apache License 2.0 with Runtime Library Exception.**

File descriptor handling for the WASI bridge.

<https://github.com/apple/swift-system>

## ZIPFoundation 0.9.20

Copyright © 2017–2025 Thomas Zoechling. **MIT License.**

Archive reading for project import.

<https://github.com/weichsel/ZIPFoundation>

## go-cmp v0.6.0

Copyright © 2017 The Go Authors. **BSD 3-Clause License.**

Shipped as Go source so one example project builds against a real dependency
with no network. Its own `LICENSE` ships with it at
`VendoredModules/github.com/google/go-cmp/LICENSE`.

<https://github.com/google/go-cmp>

## Packages you install

Modules installed through the Packages screen are downloaded from
`proxy.golang.org`, verified against `sum.golang.org`, and vendored into your
project as source. They remain under their own licences, and each module's
licence files are vendored with it. GopherForge neither relicenses them nor
claims any rights in them.
