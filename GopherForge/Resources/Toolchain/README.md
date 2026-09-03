# Toolchain

This directory holds the bundled Go-on-Wasm toolchain, and it is empty in a
fresh checkout on purpose. Build it:

    scripts/build_toolchain.sh

That produces `go<version>-wasm-1/` from the Go installation already on the
machine — `compile.wasm`, `link.wasm`, `vet.wasm`, `gofmt.wasm` and the
standard library's export data. The app discovers whatever is here at launch,
so nothing else has to be configured. It also writes
`toolchain-provenance.json`, which records the Go release and says plainly that
this one was built locally rather than from a pinned artifact.

The current artifact is Go 1.27.1 and about 220 MB, of which 138 MB is export
data for 370 standard-library packages.

Nothing in here is committed. It is build output cut from a stock Go release
with no patches, which makes it something to reproduce rather than something to
store — and a release does not reproduce it at all, it unpacks a pinned
artifact whose hash and Go version are both checked. See
[docs/TOOLCHAIN.md](../../../docs/TOOLCHAIN.md#which-go-and-how-a-release-proves-it).
