# Third-party notices

GopherForge is proprietary software. The components below are bundled or linked
under their own licences. Nothing here is relicensed. Unknown terms — including
any Go module you vendor later — stay with that module's own `LICENSE` file.

Apple's binary scan sees four WebAssembly tools and a zipped standard library.
Those are **unmodified upstream Go**, not third-party native iOS libraries.
`goroot.zip` keeps the `.a` export archives out of iOS's library scan. Zip
reading is this app's own code, not a third-party archive library. Each
family is grouped below so a reviewer can match licence to binary.

---

## BSD 3-Clause

Redistribution of source and binary forms is allowed with the copyright notice
and disclaimer. The Go toolchain ships as WebAssembly binaries, so Go's own
`LICENSE` and `PATENTS` travel beside them.

### The Go toolchain and standard library

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

### go-cmp v0.6.0

Copyright © 2017 The Go Authors. **BSD 3-Clause License.**

Shipped as Go source so one example project builds against a real dependency
with no network. Its own `LICENSE` ships with it at
`VendoredModules/github.com/google/go-cmp/LICENSE`.

<https://github.com/google/go-cmp>

---

## MIT License

Permission is granted to use, copy, modify and distribute, provided the
copyright notice and permission notice appear in all copies.

### WasmKit 0.3.1

Copyright © 2020 Akio Yasui. **MIT License.**

The WebAssembly interpreter that runs both the bundled toolchain and every
program this app builds. WasmKit includes derived code from Swift System and a
derived Swift keyword list from Swift Syntax, both Apache-2.0; see the upstream
`NOTICE.txt` for those attributions.

<https://github.com/swiftwasm/WasmKit/tree/0.3.1>

Module zips and the bundled `goroot.zip` are read by this app's own zip
reader. There is no third-party zip library in the binary.

---

## Apache License 2.0 with Runtime Library Exception

Use, reproduction and distribution under Apache-2.0. The Swift runtime library
exception allows linking these libraries into a proprietary application without
forcing that application under Apache-2.0.

### swift-system 1.8.1

Copyright © Apple Inc. and the Swift System project authors.
**Apache License 2.0 with Runtime Library Exception.**

File descriptor handling for the WASI bridge.

<https://github.com/apple/swift-system>

### swift-nio 2.101.3

Copyright © Apple Inc. and the SwiftNIO project authors.
**Apache License 2.0 with Runtime Library Exception.**

Pulled in by WasmKit. Listed here because it is linked into the app, not
because this project talks to it directly.

<https://github.com/apple/swift-nio>

### swift-collections 1.6.0

Copyright © Apple Inc. and the Swift Collections project authors.
**Apache License 2.0 with Runtime Library Exception.**

Pulled in by WasmKit.

<https://github.com/apple/swift-collections>

### swift-atomics 1.3.1

Copyright © Apple Inc. and the Swift Atomics project authors.
**Apache License 2.0 with Runtime Library Exception.**

Pulled in by WasmKit.

<https://github.com/apple/swift-atomics>

### swift-log 1.15.0

Copyright © Apple Inc. and the Swift Log project authors.
**Apache License 2.0 with Runtime Library Exception.**

Resolved with WasmKit.

<https://github.com/apple/swift-log>

### swift-argument-parser 1.8.2

Copyright © Apple Inc. and the Swift Argument Parser project authors.
**Apache License 2.0 with Runtime Library Exception.**

Resolved with WasmKit. It is a SwiftPM dependency of that package, not an
API this app calls.

<https://github.com/apple/swift-argument-parser>

---

## Unknown or their own terms

### Packages you install

Modules installed through the Packages screen are downloaded from
`proxy.golang.org`, verified against `sum.golang.org`, and vendored into your
project as source. GopherForge does not know every licence in the Go
ecosystem in advance. Each module's own `LICENSE`, `LICENCE` or `NOTICE`
is vendored with it. Until that file is present, treat the terms as
**unknown** and do not assume MIT or Apache. GopherForge neither relicenses
them nor claims any rights in them.
