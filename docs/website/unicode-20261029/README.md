# Go strings and Unicode lab

Original GopherForge examples, researched and tested 29 October 2026 for the
8 October archive edition. Article: https://gopherforge.app/news/go-strings-unicode-bytes-runes-graphemes

## Run

The root module contains only standard-library code (Go directive 1.25).
The optional nested `normlab` module pins `golang.org/x/text v0.43.0`
(Go directive 1.26.0). Actual validation used Go 1.27.3 on macOS arm64.

```sh
go run ./textlab
go test -race -count=50 ./...
go vet ./...
go test ./textlab -run '^$' -fuzz FuzzBytePrefix -fuzztime=5s -parallel=2
cd normlab
go mod download
go run .
go test -race -count=50 ./...
go vet ./...
```

Use a compatible installed compiler. First compiler/dependency setup requires
network access or an existing verified cache. The recorded offline checks used
the installed Go 1.27.3 executable directly with `GOTOOLCHAIN=local` and
`GOPROXY=off`. Module and checksum verification were performed during setup;
disabling checksum verification globally is not recommended. Root `go test
./...` does not cross the nested module: run both commands above.

Both main packages also compiled for `GOOS=wasip1 GOARCH=wasm`. Compilation is
not proof that every mobile runtime can load the optional module. No remote
services are started by these examples; streaming tests use synthetic readers.

## Contracts and limits

- Prefix functions reject malformed UTF-8 anywhere in the input and negative
  budgets. `PrefixBytes` returns the longest valid code-point prefix within the
  byte budget. `PrefixRunes` counts code points. Both copy output storage with
  `strings.Clone`; neither preserves complete grapheme clusters.
- `CountUTF8` counts the valid prefix, accepts a valid U+FFFD, rejects malformed
  encodings and preserves reader failures. A small working buffer does not
  bound total input, caller blocking time or transformation expansion.
- `ASCIIKey` is a deliberately narrow wire-key policy, not a name validator.
- `CanonicalLabel` is an NFC display-data example, not a security identity,
  password, filesystem or signed-payload policy. NFC and NFKC differ. Folding
  and normalization differ. Confusables are not resolved by NFC.
- We do not implement grapheme segmentation, a confusable detector or a complete
  Unicode conformance suite. The tested compiler and normalizer both report
  Unicode 17.0.0. Current cited Unicode documents describe 18.0.0. The pinned
  normalizer's selected tables depend on compiler build tags.
- Stateful normalization differs from normalizing chunks separately. Long
  non-starter sequences exercise stream-safe CGJ insertion in the pinned
  implementation. Do not assume normalization preserves byte-exact payloads.

## Verification evidence

Both modules passed race-enabled tests repeated 50 times and `go vet`. The
fuzzer completed 64,481 executions without failure in this recorded short run.
Six deliberately broken variants failed their targeted tests; see
`negative-controls.json`. These are bounded observations, not universal
correctness, performance or standards-conformance claims.

`text-output.txt` and `norm-output.txt` contain observed example output.
`research.json` records versions and primary sources. `source-hashes.json`
identifies the source and evidence files included in the downloadable bundle.
Illustration prompts, originals, final assets and SHA-256 values are recorded
separately in repository `assets.json` (built-in image_gen mode).
