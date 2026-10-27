# Go JSON v2 migration: runnable companion

Companion to [Go JSON v2 migration: keep your API contract intact](https://gopherforge.app/news/go-json-v2-migration-api-compatibility).

Requires Go 1.27. The module records Go 1.27.3 as the preferred toolchain; no third-party dependencies or experimental flags are required for that release. A Go installation with automatic toolchain downloads enabled can select that version when needed. The explicit environment setting below reproduces the article checks.

```sh
export GOTOOLCHAIN=go1.27.3
go version
go run ./cmd/compare
go test ./...
go test -race ./...
go test -run '^$' -fuzz FuzzDecodeUpdate -fuzztime 10s -parallel 2
go test -run '^$' -bench BenchmarkMarshal -benchmem -count=5
```

The comparison executable demonstrates nil collection representations, `omitempty` behavior, compatibility options, and duplicate-name rejection. Tests additionally cover exact versus case-insensitive member matching, invalid UTF-8, unknown members, trailing data, omission with `omitzero`, and fresh comparison targets.

`MarshalCompatible` uses the v2 API with v1 options. `MarshalEmptyItems` opts into one formatting change. `DecodeUpdate` is a strict **full update**, not a PATCH representation: it does not distinguish an absent boolean from an explicit false, or absent properties from explicit nulls. The caller must bound input size and perform authorization before side effects.

The decoder returns a zero value on failure and validates a nonblank name before publishing a value. The fuzz property checks successful typed round trips and ensures failed decodes do not publish partial values. Input length is capped in the fuzz target to keep local campaigns bounded.

The benchmark compares a nonnil fixture with the same intended output and includes deterministic v2 encoding. It does not claim that v2 is universally faster. Profile a representative workload with the exact toolchain and options used in production.

For broader migration coverage, include custom methods, embedding, persisted JSON, client schemas, exact-byte contracts and consumer-specific fixtures. Do not use shadow decoding to repeat business operations, and do not log customer payloads as comparison diagnostics.
