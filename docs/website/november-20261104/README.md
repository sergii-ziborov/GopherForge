# Go engineering editions, 30 October–4 November 2026

Six original guides fill every empty edition after 29 October through the
client's current date, 4 November. Actual first publication and source checks
are recorded as 4 November, separately from archive editions.

| Edition | Subject | Prose words, excluding code |
|---|---|---:|
| 30 October | Generics, interfaces and API contracts | 2304 |
| 31 October | Embedded web assets and routing | 2272 |
| 1 November | Redis cache stampedes and singleflight | 2313 |
| 2 November | MongoDB cursors, indexes and transactions | 2218 |
| 3 November | OpenTelemetry and propagation | 2251 |
| 4 November | Fuzz tests and durable regressions | 2225 |

Each guide has three distinct built-in ImageGen illustrations. `assets.json`
records exact prompts, original PNG paths, final project WebP paths, alt text,
dimensions and SHA-256 hashes. Contact sheets were inspected before integration.
The images are conceptual, not database plans, telemetry or benchmark results.

## Original lab

Use the `lab/` directory in the repository, or the root of the downloadable ZIP.
The selected compiler is Go 1.27.3. The Go 1.27 language requirement is explicit
because `genericlab` demonstrates generic methods. Dependencies are pinned to
OpenTelemetry v1.47.0 and x/sync v0.24.0, with go.sum included.

```sh
go mod download
go test -race -count=10 ./...
go vet ./...
go test ./fuzzlab -run '^$' -fuzz FuzzParse -fuzztime=5s -parallel=2
```

Initial setup requires module access or a populated cache and an installed
compatible compiler. Cached tests also passed with `GOPROXY=off` and the installed
Go 1.27.3 executable selected directly (`GOTOOLCHAIN=local`). No Redis, MongoDB,
collector or network listener is started. Database behavior, real query plans,
production throughput and remote exporter delivery are not claimed by the lab.

The six packages test generic relationships and ownership, embedded HTTP routes,
duplicate work and independent waiters, bounded cursor ownership, in-memory
trace parent relationships, and a bounded UTF-8 record grammar. Six intentional
mutations failed targeted tests. The short fuzz campaign completed 650,458
executions without failure; it is not an exhaustive correctness claim.

`research.json` records article sources, dates, versions and experimental scope.
`negative-controls.json` records intended failures. Test logs and source hashes
are included in the downloadable bundle. No native app binary or App Store
submission changes are part of this publication.
