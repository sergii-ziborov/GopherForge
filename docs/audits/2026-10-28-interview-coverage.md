# Go interview coverage audit — 28 October 2026

The source and web catalogs now contain **220 teaching lessons**, including **173 readings**, plus **22 prediction challenges**, across **28 units**. Interview contains **132 worked guides**, **15 topics**, four levels and the existing **12 interactive algorithm demonstrations / 36 cases**. Native curriculum: **1.3.1 (49), VALID / IN_BETA_TESTING in Internal QA TestFlight**. The current **1.3.1 (49)** App Review submission includes the expansion and supersedes the earlier 1.3.0 (48) candidate.

## Additions

| Area | New lessons | What the learner must explain |
|---|---:|---|
| System design | 9 | Transaction ownership, outbox/inbox, sagas and unknown outcomes, compatible rollout, tenant isolation, telemetry cardinality, gRPC/Protobuf, Kafka offset prefixes, per-operation consistency under partitions |
| Clean code in production | 4 | Composition and cleanup lifetime, context ownership, consumer contracts/test seams, exact time/money units and presence |
| Around Go: Gin | 6 | Middleware chain and Abort, bounded binding versus validation, pooled context lifetime, trusted proxies, one error response, graceful drain and long-lived connections |
| Around Go: blockchain | 7 | Package roles, bounded RPC and chain identity, exact token values, ABI calls versus transactions, nonce ownership/unknown outcomes, signing policy/key custody, reorg-safe indexing and finality |
| Around Go: security | 4 | Identity versus object authorization, MAC/password/KDF purposes, SSRF and redirect/egress policy, TLS peer identity |
| Existing concurrency and stdlib units | 4 | Immutable atomic publication, lock ownership/copy hazards, timer contracts, bounded HTTP response ownership |
| **Total** | **34** | Every reading has worked code, explanatory sections, a flow, references, an independent matching pair and three-choice review |

**40 additional interview guides** turn these into concrete failure cases and follow-ups. Six further cases cover strict sorting/stability contracts, iterative directed-cycle detection, Floyd cycle entry, rendezvous hashing, cancellation barriers and partial writes. The four new algorithm guides are worked-code guides; they are not advertised as additional interactive trace labs.

Architecture & clean code now groups **four units / 40 lessons**: the existing 19 architecture and eight clean-code lessons, plus the two production units above. Existing 23 classic patterns, six Go resilience/concurrency patterns, MongoDB/Redis, SQL, modules/tooling, Docker/Kubernetes and coding-agent content remain available.

## Coverage map

| Interview track | Existing coverage retained | Added depth |
|---|---|---|
| Language and types | Zero values, slices/arrays, maps, strings/runes, interfaces/typed nil, method sets, errors/defer/panic, generics, iterators | Modern generic-method restrictions; expression-form new; Writer partial results |
| Runtime and concurrency | GC/escape, scheduler, memory model, channel ownership, cancellation, bounded workers, race diagnosis, profiles | Atomic publication, lock copying, select cancellation, timer lifetime, deterministic barriers |
| Algorithms | Search, windows, heaps, graphs, DP, merge, topological order, union-find, LRU, intervals | Sorting contracts, DFS cycle detection, linked-list cycle entry, rendezvous hashing |
| Backend and data | HTTP, JSON contracts, SQL transactions/pools, MongoDB, Redis, failure/load limits | Gin request lifecycle, gRPC streams/status/deadline, Kafka commit prefix, transaction/event durability |
| Architecture | Monoliths, layered/hexagonal/clean/onion, DDD, CQRS, events, services, patterns and editorial suitability ratings | Cross-system recovery, mixed deployments, tenant boundaries, dependency lifetime, exact units |
| Security and protocol infrastructure | Existing trust and generated-code review | JWT verifier policy/object access, TLS, SSRF, cryptographic purposes, Ethereum/Bitcoin/Cosmos package roles and state reconciliation |
| Delivery and tooling | Modules/MVS, checksums/private modules/workspaces/vendor, test/fuzz/benchmark/profile, Bash/Git, Docker/Kubernetes | Operational contracts connected to service/consumer failure cases |
| Coding agents | Four course readings / eight worked guides on Codex, Claude Code and Cursor | Retained with small-change, API verification, cancellation/ownership, repository-context and trust checks |

This is a broad preparation map, not a guarantee that a finite course contains every question any company could ask. Difficulty labels are editorial guidance. Protocol SDKs, native HTTP/database servers and production infrastructure are studied in a native development environment. Adding these lessons does not add wallets, public RPC access, registration, cloud execution or guest networking to the app.

## Corrections to existing material

- `collections.make-and-new` preserves its ID, task and completion contract. Its wording now distinguishes `new(T)` from Go 1.26+ `new(expr)` rather than claiming new only allocates zero values. The matching answer is updated too.
- `language.generics` now includes Go 1.27 concrete generic methods and the restriction on generic interface methods. Existing Go 1.27 lesson examples were preserved, not downgraded to an older compiler's syntax.
- Three broken reference paths were replaced with authoritative Ethereum/GNU/author-hosted resources. Initial link audit: 287 successful responses, three 404s, one 403 and 52 rate-limited responses. Access restrictions are not presented as proof of broken content.
- Every prior lesson/question ID remains present. Existing payloads are otherwise preserved except the documented corrections/reference repairs. No progress format or migration was changed.

## Publication

The [expanded course](https://gopherforge.app/learn) and [Interview](https://gopherforge.app/interview) are live. The shared catalog, app guide, release availability, metadata and sitemap are synchronized. Fifteen representative public HTTPS routes and all 74 new lesson/question sitemap entries passed checks. [Website receipt](../website/2026-10-28-curriculum49-publication.json).

## Verification

- **40 new complete Go examples executed with semantic output assertions**, native Go 1.27.3. Pinned QA dependencies: Gin v1.12.0, go-ethereum v1.17.10 and gRPC v1.85.0. Dependencies were prepared first; execution disabled registry access and used only explicit local httptest servers. No public RPC, transaction broadcast or private key was used.
- **All 92 complete programs in ReadingLessons.json compile** on that native toolchain. Incomplete teaching fragments are excluded from this compile gate and are not claimed to be executable programs.
- **12 existing interactive algorithm implementations** passed boundary tests, 500 randomized comparison rounds and 200 additional property rounds under the race detector.
- **27 website tests passed**, including exact native/web parity, unique lesson routes, complete direction/topic membership and local progress restoration.
- Next.js production build passed. The sitemap and metadata include the new lesson/unit/question routes and content edit dates; release history distinguishes public, review and curriculum candidate versions.
- **43 focused native checks passed**: 39 model checks and four UI flows, including Gin/blockchain navigation, reading Continue after relaunch, existing interview self-assessment persistence and restoration of a learner’s own edited source. Simulator checks do not certify physical-device airplane-mode behavior. The finalized Xcode result bundle reports Passed (43 passed, zero failures).
- Browser verification retained the existing completion mark and restored a new lesson’s exact section after reload.

Reproduce the example checks with `GO=/path/to/go1.27.3 python3 scripts/verify_curriculum_examples.py` and `python3 scripts/verify_interview_algorithms.py` using the selected Go toolchain on PATH. These checks validate native examples, not an unrestricted WASI environment or a real blockchain node.

## Final publication recheck

The final check found the curriculum build had reached TestFlight while App Review still used build 48. The review was replaced with **1.3.1 (49)**, automatic release enabled, descriptions and review notes updated, and **12 fresh Course/Interview screenshots across six native sizes** delivered. All 55 listing screenshots and both creative placements were checked. See [submission receipt](../releases/1.3.1-build49-submission.json) and [asset receipt](../releases/1.3.1-build49-assets.json). Current site/guide/README labels and the guide course image were updated too.
