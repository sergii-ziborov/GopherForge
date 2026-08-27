# Toolchain

This directory holds the bundled Go-on-Wasm toolchain, and it is empty in a
fresh checkout on purpose. Build it:

    scripts/build_toolchain.sh

That produces `go<version>-wasm-1/` from the Go installation already on the
machine — `compile.wasm`, `link.wasm`, `vet.wasm`, `gofmt.wasm` and the
standard library's export data — in about fifteen seconds. The app discovers
whatever is here at launch, so nothing else has to be configured.

Nothing in here is committed. It is roughly 180 MB of build output cut from a
stock Go release with no patches, which makes it something to reproduce rather
than something to store.
