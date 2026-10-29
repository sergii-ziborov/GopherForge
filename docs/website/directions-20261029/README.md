# Go directions research and structured logging lab

Original guides for the **6 and 10 October 2026 archive editions**. Research and first publication: **29 October 2026**, not the archive dates. These articles add no app telemetry, accounts or tracking.

## Research provenance

- `research.json` names each primary source, edition, observation and limitation. TIOBE October 2026 shows Go at 11 (1.39%) and explicitly changes its method to include Mandarin queries. PYPL Worldwide October 2026 shows Go at 17 (0.53%). RedMonk January 2026, published 14 April, shows Go at 12. Octoverse 2026 includes Go among its top-ten language participation series; no unsupported Go-specific growth percentage is asserted.
- `trends-*-ui-tables.json` preserves public accessible chart tables read through the actual Google Trends UI. Filters: Worldwide, Past 5 years, All categories, Web Search. The `golang` search term and Go Programming language topic were retrieved separately. Topic selection was observed in autocomplete, not guessed. Screenshots retain filter context.
- The current partial week beginning 25 October is excluded. Latest 52 complete weeks: 26 October 2025–18 October 2026. Previous block: 27 October 2024–19 October 2025. Each block has 52 observations. `trends-summary.json` records the means: topic 70.37→61.67; term 63.94→42.56.
- Separate normalization prevents using the row magnitudes to infer absolute volume between queries. Searches are not developers, deployments, jobs or market share. PYPL also uses Google Trends and is not independent adoption evidence.
- `pypl-ui-table.json` preserves the observed current worldwide table. We do not rely on third-party summaries with conflicting ranks or shares.
- The 2025 official Go survey supplies use-case evidence from its own respondent population. The 2026 survey is still open at the research date; no 2026 results are invented. Project repositories establish available implementations, not their aggregate adoption rate. Forward-looking application directions are explicitly original engineering assessment.

Reproduce the averages from the saved UI data (not live endpoints):

```sh
python3 analyze_trends.py
python3 -m unittest test_trends.py
```

Three tests exercise partial-week exclusion, a missing-week rejection and out-of-range scores. Live Trends can be resampled or revised; these calculations describe the saved retrieval.

## Original Go lab

`go.mod` declares Go 1.25. The recorded compiler is **Go 1.27.3, darwin/arm64**. Everything uses the standard library, fabricated values and in-memory writers. No network listeners, services, user credentials or third-party modules are needed.

```sh
go version
go test -race -count=50 ./...
go vet ./...
go run ./sloglab
```

Prefix with `GOTOOLCHAIN=go1.27.3` to select the recorded compiler. First use may download the official Go toolchain; that is separate from executing the dependency-free lab offline once the compiler is installed.

The program emits two JSON demonstration records and separate argument-count/writer-error observations. Its selected 120 ms elapsed value is synthetic, not a benchmark. Test assertions decode JSON instead of depending on whitespace or key order.

Verified boundaries:

- Root service/request ID fields and grouped route/status/duration/outcome preserve the declared schema, including when the passed context has already been canceled.
- Request IDs are synthetic; a real service must define approved IDs. Routes are trusted templates. Never substitute raw URLs, paths, query strings, headers, bodies or temporary capability links. The constructor does not sanitize arbitrary caller text.
- Typed Secret uses LogValuer; converting it to string loses that protection. ReplaceAttr masks only the named keys authorization/password/token. Neither mechanism scans all personal data or repairs secrets embedded in messages or arbitrary objects.
- Error classification does not copy the error message. INFO versus ERROR is a deliberate example policy based on status, not a universal severity rule.
- An Enabled guard avoids building a disabled debug summary. An eager argument still runs before a discarded call; a counter, not an invented performance percentage, verifies this.
- Ordinary Logger output has no error return. A failing writer is observed through a direct handler call in the test. No successful application operation or log method call is a durable delivery guarantee.
- Sixteen concurrent child events decode correctly after joining; the child group does not mutate the root. This does not certify arbitrary third-party handlers or writers.

The correct suite passed 50 race-detector runs and go vet. Four temporary negative controls each failed the intended test: leaking typed secrets, omitting the request group, assigning the wrong server-failure level and removing the debug guard. Correct source only is distributed. The standalone program cross-compiled for wasip1/wasm; runtime execution in every host is not implied.

## Playground exercise

Save/download your existing draft before copying the complete `sloglab/main.go` into the editor, with a compatible module. Editing does not execute Go or create a room. If collaborating, deliberately create a temporary room, open it in a compatible native app and press Run on that selected device. The relay shares source and device-attributed output. An assistant edit does not automatically execute code. Native capabilities and expiry are described in the website MCP guide.

Try one change at a time and predict it: change severity, remove grouping, convert a Secret to string, enable DEBUG, or replace the writer with a controlled failing implementation. Restore the protected version before using real inputs. These are educational diagnostics, not an audit-log persistence system.

## Images and publication

`assets.json` records all six exact prompts, built-in ImageGen mode, preserved original PNG locations, published 1536×1024 WebPs, alt text, sizes and SHA-256 hashes. Each article has a hero, detail illustration and infographic. The conceptual images do not draw fabricated popularity charts.

The public download includes source, research tables and provenance, not the locally saved browser screenshots or generated image originals. `source-hashes.json` lets readers verify every included file. Publication verification records canonical metadata, TechArticle dates, images, internal links, sitemap and RSS separately from the native Go checks.
