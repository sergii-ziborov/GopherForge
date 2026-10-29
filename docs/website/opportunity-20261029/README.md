# Go hiring evidence and context deadline lab

Original GopherForge guides for the **7 and 9 October 2026 archive editions**. Research and actual first publication: **29 October 2026**. The career guide includes a Djinni report published on 29 October and does not claim that it was available on the archive date.

## Editorial and source evidence

`editorial-gap-analysis.json` records the existing 30-article catalog, two distinct search intentions, related learning paths and limits of the SEO assessment. No keyword volumes, ranking difficulty, future traffic or guaranteed search position are invented. No new product logging or visitor tracking is introduced.

`research.json` records primary sources, date windows, units, denominators and the exact scope of each claim. The article uses public aggregate reports, not private profiles, contacts, applications or salaries of identifiable people.

`djinni-golang-widget.json` contains the observed public chart labels and filter selection. The browser selected **Golang only**, retaining all three experience groups, all country groups and all search-duration groups. The chart describes recorded hiring within three months after opening contacts. The displayed 2024/2025/2026 percentages are 8.2%, 7.9% and 3.2%; **2026 is Q1–Q2 only**. Candidate-count labels are rounded as displayed; no exact numerator or full-year estimate is inferred. Two screenshots preserve the filter and chart views.

The separate April Djinni report analyzes almost 2,300 already-hired people with a six-month lookback. Its median ten applications is not a personal success probability or a Go-only statistic. Incoming recruiter propositions are not automatically final employment offers. DOU's survey medians are monthly USD after tax, while Djinni's Q1 salary caveat concerns profile expectations at the start of recruiter contact. Golang Cafe counts a different tracked career-page population and distinguishes required Go from a language mention.

Run the original synthetic selection-bias example:

```sh
python3 hiring_scenarios.py
```

Both invented cohorts have ten hired candidates with a median of ten applications. Adding ten versus 190 other candidates gives observed hiring shares of 50% versus 5%. The script asserts both results. These are constructed examples, not reconstructed Djinni candidates, personal forecasts or a hiring model.

## Go context lab

The module declares **Go 1.25**. Recorded validation uses **Go 1.27.3, darwin/arm64**. All code uses the standard library. Tests supply custom HTTP transports; they do not resolve the illustrative `.invalid` host or make network calls. No listeners, databases, external gRPC services, credentials or third-party modules are required.

```sh
go version
go test -race -count=50 ./...
go vet ./...
go run ./contextlab
```

Use `GOTOOLCHAIN=go1.27.3` to select the recorded compiler. First use may download the official toolchain; once installed the example itself needs no network.

Verified boundaries:

- An hour-long child request cannot extend a parent's earlier ten-millisecond deadline.
- A local three-second child budget expires with a deliberately named cause while the hour-long parent remains active. These are virtual-time semantic examples, not production timeout recommendations.
- Local cancellation/deadline error identity survives `%w` wrapping. The stage checks already-known cancellation before work. The later select does not promise priority when completion and cancellation become ready simultaneously.
- Cancellation does not prove cleanup completion. The owner releases an explicit cleanup gate and receives the result; the test observes non-completion before release.
- A two-second HTTP client timeout can return a deadline-classified error while the original request context remains active. The test transport waits for its supplied request context; no network is used.
- Immediate synthetic HTTP success remains readable and its response body is closed.

The tests use `testing/synctest` bubbles, explicit channels and controlled transports. Real socket I/O is not durably blocked inside the virtual-time mechanism. The suite passed **50 race-detector runs**, `go vet`, and four negative controls. Temporary variants with lost parent propagation, discarded wrapping, incorrect cancellation identity and skipped cleanup each failed the intended test. Correct source only is distributed.

The standalone program cross-compiled for **wasip1/wasm**. This confirms target compilation, not execution inside every Wasm host. The article's real SQL and gRPC discussion comes from primary documentation; these external systems were not integration-tested by this lab.

## Playground exercise

Save your current draft before copying the complete `contextlab/main.go` into the editor with a compatible module. Editing does not run Go. Deliberately create a temporary room if collaborating, then press Run on the selected compatible native device; the relay carries source and device-attributed output. An AI edit does not silently execute code. See the website MCP guide for capabilities, expiry and execution ownership.

Inspect one distinction at a time: expired deadline versus explicit cancellation; standard error identity versus named cause; cancel signaling versus observed completion. Do not substitute `WithoutCancel` as a general fix for unowned work. The example is not a durable background-job system or proof that a remote effect rolled back.

## Images and publication

`assets.json` records six exact prompts, **built-in ImageGen** mode, preserved original PNG paths, published 1536×1024 WebPs, alt text, sizes and SHA-256 hashes. Each article has a hero, detail and infographic. The conceptual illustrations do not draw invented salary statistics or hiring forecasts.

The public ZIP contains source, source register, observed widget labels, synthetic calculation and README, with `source-hashes.json` for integrity. It excludes screenshots, generated originals and local filesystem image paths. Publication checks verify metadata, actual dates, canonical URLs, three images per article, learning links, RSS, sitemap and source hashes. Native App Store submissions are outside this article-only update.
