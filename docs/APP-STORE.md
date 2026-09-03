# Submitting GopherForge to the App Store

Everything the source tree can settle is settled. What is left needs an
App Store Connect account and is listed at the end.

---

## 1. What this app is, for a reviewer

GopherForge teaches the Go programming language and compiles it on the device.
The Go compiler, linker, vet and gofmt ship **inside the app**, cross-compiled
to WebAssembly, and run in an interpreter. There is no server: the app builds
and runs Go with the network switched off.

The parts a review will ask about are covered below, each with the answer and
where in the tree to verify it.

---

## 2. Guideline 2.5.2 — software that installs or launches executable code

This is the guideline that matters most for this app, so it is answered in
full.

**The guideline's exception.** Apps designed to teach, develop or test
executable code may download and run code, provided the source is completely
viewable and editable by the user, and provided the downloaded code does not
change the app's own features.

**What GopherForge actually does.**

| Claim | Where to verify |
| --- | --- |
| The compiler is **bundled**, not downloaded. Nothing executable is ever fetched. | `GopherForge/Resources/Toolchain/`, built by `scripts/build_toolchain.sh` |
| The only things downloaded are **Go source files** — module source from `proxy.golang.org`, repository snapshots from `codeload.github.com`. Both are text. | `GoModuleProxyClient.swift`, `GitHubRepositoryImporter.swift` |
| Downloaded source is **vendored into the open project as ordinary files**, listed in the navigator beside the user's own, and editable in the same editor. Nothing is hidden. | `GoVendorWriter.swift`; `ProjectNavigatorView.swift` lists every key of `project.files` with no filter |
| Module downloads are **verified against the Go checksum database** before anything is written. | `GoChecksumDatabase.swift`, `GoModuleHash.swift` |
| Compiled programs run in a **WebAssembly interpreter**, not natively. They cannot call into the app, into iOS, or into any other process. | `WasiProcessRunner.swift` |
| A user program gets **one writable directory** (`/sandbox`), a memory cap and a table cap. It has no network: `wasip1` has no outbound socket API, so `net.Dial` fails by construction. | `WasmSandboxPolicy.swift` |
| Nothing a user compiles can change the app's features. The interpreter's output is text and image files the app displays. | `GoProgramArtifacts.swift` |

**Suggested App Review note** (copy into the review notes field):

> GopherForge is a Go programming environment for learning and development.
> The Go toolchain (compiler, linker, vet, gofmt) is compiled to WebAssembly
> and bundled inside the app — no executable code is ever downloaded. The app
> optionally downloads Go **source code** from the public Go module proxy and
> from GitHub at the user's request; that source is written into the user's
> project as ordinary files and is fully viewable and editable in the app's
> editor. Programs the user compiles run inside a sandboxed WebAssembly
> interpreter with one writable directory, a memory limit, and no network
> access. Nothing downloaded or compiled can alter the app's own functionality.
>
> What a reviewer may want to confirm, in order:
>
> 1. Open the app — no account, no sign-in, no purchase; every feature is
>    available immediately.
> 2. Tap **Build** and press **Run** on the sample project. It compiles and
>    runs with no network; airplane mode is a fair test.
> 3. Edit the source in the editor and press Run again — the output changes,
>    because the code is compiled on the device rather than matched against
>    anything.
> 4. Open **Projects → My projects** and then the file navigator to see that
>    everything the app has downloaded is source, listed beside the user's own
>    files and editable in the same editor.
>
> What the app is not: it is not a store for executable content. Nothing it
> downloads can add a feature to GopherForge, the package browser lists
> published Go modules for a project's own dependencies rather than anything
> installable into the app, and a compiled program cannot call into iOS — it
> runs in a WebAssembly interpreter with one writable directory, a memory cap,
> and no network API in scope at all.

---

## 3. Privacy

- **App Privacy answers:** *Data Not Collected*, for every category.
- `PrivacyInfo.xcprivacy` ships in both the app and the share extension.
  `NSPrivacyCollectedDataTypes` is empty and `NSPrivacyTracking` is false.
- Two required-reason APIs are declared, with reasons:
  `NSPrivacyAccessedAPICategoryFileTimestamp` (**C617.1**, evicting the oldest
  entries from the on-device build cache) and
  `NSPrivacyAccessedAPICategoryUserDefaults` (**CA92.1**, the app's own
  settings through `@AppStorage`).
- No analytics SDK, no crash reporter, no advertising identifier, no account.
- The policy text is in [`PRIVACY.md`](../PRIVACY.md) and must be published at a
  public URL before submission — App Store Connect requires one for every app.

**Hosts contacted, all HTTPS, all only when the user asks:**
`deps.dev` and `api.deps.dev` (package search and ratings), `proxy.golang.org`
and `sum.golang.org` (module download and checksum verification),
`codeload.github.com` (repository import). No App Transport Security exceptions
are declared.

---

## 4. Export compliance

`ITSAppUsesNonExemptEncryption` is declared **false** in `Info.plist`.

The app uses encryption in exactly two ways, both exempt:

1. **HTTPS** through `URLSession`, using the operating system's own TLS. Using
   the platform's HTTPS for ordinary transport is exempt.
2. **SHA-256** through CryptoKit, to compute Go module hashes (`h1:`) and build
   cache keys. A hash is not encryption; this is integrity checking, which is
   exempt in its own right.

There is no proprietary or non-standard cryptography anywhere in the app.

---

## 5. Third-party software

Everything bundled is listed in `GopherForge/Resources/ThirdPartyNotices.md`,
which ships inside the app and is shown under **Settings → Acknowledgements**.
`ThirdPartyNoticesTests` fails the build if a dependency is missing from it or
recorded under the wrong licence.

| Component | Licence |
| --- | --- |
| The Go toolchain and standard library | BSD 3-Clause (`LICENSE` and `PATENTS` ship in `goroot/`) |
| WasmKit | MIT |
| swift-system | Apache 2.0 with Runtime Library Exception |
| ZIPFoundation | MIT |
| go-cmp | BSD 3-Clause |

`scripts/build_toolchain.sh` **refuses to produce a toolchain artifact** unless
Go's `LICENSE` and `PATENTS` are staged alongside it, because shipping the
compiled tools without them would not satisfy the BSD 3-Clause binary
redistribution terms.

The app does not use the Go Gopher. The mark is original artwork; the Gopher is
Renée French's, and the notices say so.

---

## 6. Other guidelines considered

| Guideline | Position |
| --- | --- |
| **1.2 User-generated content** | The package browser lists module names and scores from `deps.dev`, a Google-operated index of published packages. This is a package registry, not user-generated content: there is no posting, no profiles, no messaging between users, and nothing a user of this app can publish to it. |
| **2.3.1 Hidden features** | None. Every feature is reachable from the UI and described in the listing. |
| **3.1.1 In-app purchase** | The app is paid up front and contains no in-app purchases, no subscription, and no purchase surface of any kind. Every feature is available to a reviewer on first launch with no account and no unlock. |
| **4.7 Mini apps** | Not applicable; 2.5.2's developer-tool exception is the governing rule, and the app hosts no third-party mini-app store. |
| **5.1.1 Data collection** | Nothing is collected, so no consent flow is required and none is shown. |
| **iOS data storage** | User projects and learning progress go to Application Support (backed up, because they are user-created). The build cache goes to Caches (purgeable, not backed up). Nothing large is written to Documents. |
| **Game Center** | The capability is deliberately **not** in the entitlements file. The code is written and tested, and the app reports Game Center as unavailable rather than failing. See [`GAME-CENTER.md`](GAME-CENTER.md) before enabling it. |

---

## 7. Findings from the pre-submission review

The pass over this app found seven real problems. All are fixed; they are
recorded because each one is a mistake that comes back.

1. **The app icon carried an alpha channel.** App Store Connect rejects
   transparent icons *at upload* — after the archive, after the signing. Every
   pixel was already opaque, so the channel was pure liability. Flattened, and
   `scripts/check_app_icon.sh` now fails the build if it returns.
2. **The notices recorded WasmKit as Apache 2.0. It is MIT.** Getting a licence
   wrong is worse than omitting it: it is a false statement about someone
   else's terms.
3. **go-cmp shipped as vendored source but was not listed at all.**
4. **The notices claimed Go's licence shipped inside the toolchain. It did
   not.** This was a genuine BSD 3-Clause compliance gap for a binary
   redistribution, not a paperwork detail. The build script now stages
   `LICENSE` and `PATENTS` and refuses to produce an artifact without them.
5. **No privacy manifests.** Added for the app and the share extension, with
   the two required-reason API declarations.
6. **`UIFileSharingEnabled` was true, and the app never writes to Documents.**
   It would have put an empty GopherForge folder in the Files app — a promise
   the app does not keep. Removed.
7. **The version was 0.1.0.** Set to 1.0.0 for a first release.

---

## 8. The listing

Copy for App Store Connect, within Apple's limits. Character counts are given
because the fields are truncated silently rather than refused.

| Field | Value | Limit |
| --- | --- | --- |
| Name | `GopherForge` | 30 |
| Subtitle | `Write, test and run Go offline` (29) | 30 |
| Category | Developer Tools, then Education | — |
| Age rating | 4+ | — |

**Promotional text** (170; can be changed without a new build, so it is the
place to put anything time-bound):

> A real Go compiler in your pocket. Build, vet, test and run Go with the
> network switched off — beside a 40-lesson course written for people who
> already program.

**Keywords** (100 characters, comma-separated, no spaces — a space costs a
character and buys nothing). The name and subtitle are indexed separately, so
none of their words are repeated here:

```
golang,go,compiler,ide,editor,programming,learn,code,goroutines,offline,developer,wasm,tutorial
```

The lesson and unit counts above are the ones `ListingCopyTests` checks against
the catalogue. They were wrong once — the document said forty lessons across
seven units while the app shipped forty-nine across nine — and a reviewer
comparing the listing, the screenshots and the app is exactly who notices.

**Description:**

> GopherForge is a Go workspace that runs on the device. The Go compiler,
> linker, vet and gofmt are inside the app, so you can build, test and run Go
> with the network switched off.
>
> WHAT IT DOES
>
> • Build, Run, Test, Vet and Format real Go — the toolchain is bundled, not a
>   server somewhere.
> • Read Go's own diagnostics, parsed to the line and column, marked in the
>   editor where they happened.
> • Run `go test` and see per-case results, kept apart from compiler errors.
> • Write in an editor with Go and go.mod highlighting, a keyboard row of the
>   symbols Go actually needs, and code that scrolls sideways instead of
>   wrapping.
> • Keep as many projects as you like: folders, tags, stars and search by name,
>   folder, tag or file name.
> • Import a public GitHub repository, a folder from Files, or an archive this
>   app exported.
> • Install a Go module: it is resolved through the official proxy, checked
>   against the Go checksum database, and vendored into your project — after
>   which the project builds offline.
>
> LEARNING GO
>
> • A course of 49 lessons across nine units, written for people who already
>   program and are carrying habits from another language, including the types
>   you declare yourself and generics.
> • A lesson passes when the hidden test passes. The compiler judges it, not a
>   text match — and the app records whether a pass was witnessed by the
>   compiler or reported by you.
> • Quizzes, matching drills and a review queue built from the mistakes the
>   compiler and the idiom coach actually saw you make.
> • Idiom Coach flags Java-style getters, a context that is not the first
>   parameter, discarded errors and a channel closed in the receiving
>   goroutine — each one explaining itself.
> • Concurrency Lab runs scenarios that print what your goroutines did, and
>   names the goroutine and the channel that blocked.
> • An example library of programs that run, including graphics that compute
>   pixels and write PNGs the app displays.
>
> PRIVACY
>
> No account, no analytics, no tracking, nothing collected. The app reaches the
> network only when you ask it to import a repository or install a package.
>
> WHAT IT DOES NOT DO
>
> cgo is not supported: it needs a native C toolchain. Programs you compile run
> in a WebAssembly sandbox with one writable directory and no network access.

**What's New, 1.0.0:**

> First release.

---

## 9. Price

**Decided: paid up front. No free tier, no in-app purchase.**

**Recommended: $4.99 as an announced launch price, moving to $9.99** — or
**$6.99 flat** if the price should be set once and left alone.

### What a paid app already gives the buyer

One purchase, every future version, no upgrade pricing — that is simply how a
paid iOS app works, and there is nothing to build for it. It also means the
price has to cover the work that comes after 1.0, which is an argument against
setting it too low rather than for it.

### Why not $3.99

The buyer here is not browsing. Somebody installing a Go compiler on an iPhone
arrives from a search with an intent, and that purchase is not very sensitive
to price: the difference between $3.99 and $6.99 wins few extra installs and
changes the signal a great deal. The product's claim is a real compiler, and a
four-dollar price argues with that claim before the app is opened.

### If the entry price should be lower

Do it as a launch price with a stated end — $4.99 for the first few weeks, then
$9.99 — rather than a quiet number that goes up later. An announced increase is
a reason to buy now; an unannounced one reads as arbitrary to the person who
was going to buy next week. Raising a price in App Store Connect is a single
change and never affects anyone who has already bought.

### Why $9.99 is the ceiling

One-time iOS developer tools cluster tightly. Pythonista and Textastic sit at
$9.99, Codea at $14.99, and Code App — a broader editor with SSH, a terminal
and Git — at $6.99. GopherForge is narrower than Code App and deeper in the one
thing it does. $9.99 is the most somebody pays without research; above it the
listing has to win an argument it cannot have in six screenshots.

### What paid up front costs

Conversion. An unknown paid app is bought by people who came looking for it —
somebody searching "go compiler iphone" — and almost nobody else, so the
listing has to do the whole job of explaining the difference from a tutorial
app. That is why the screenshots lead with the compiler rather than the course.

### What it saves

Everything StoreKit would have cost: a product definition, an entitlement
store, a paywall, purchase and restore flows, offline entitlement caching,
transaction observers, and the sandbox testing under all of them. It also keeps
the answer to guideline 3.1.1 simple and true — the app contains no purchases
at all — and keeps the whole app available to a reviewer without an account.

### If this is revisited later

Moving to free-with-an-unlock is a price change plus a build, not a migration,
and the natural line is between learning and working: the course, the drills,
the lab and the examples free, and your own projects, imports, packages and
export behind the unlock. It is worth doing only once the listing has reviews,
because that model's whole advantage is volume it cannot get without them.

---

## 10. What still needs an App Store Connect account

These cannot be done from the source tree.

- [ ] Create the app record for `com.sergiiziborov.GopherForge`.
- [ ] Publish `PRIVACY.md` at a public URL and enter it as the privacy policy
      URL. **Required — a submission without one is rejected.**
- [ ] Provide a support URL.
- [ ] Answer the App Privacy questionnaire: *Data Not Collected* throughout.
- [ ] Upload the screenshots. They are captured by driving the real app:
      `scripts/app_store_screenshots.sh` erases a 6.9" iPhone and a 13" iPad,
      runs `AppStoreScreenshotUITests` on each, and writes the results to
      `docs/app-store/screenshots/`. Apple scales those two sets down to the
      smaller device sizes, so no others need capturing.
- [ ] Paste the name, subtitle, keywords, promotional text and description from
      section 8.
- [ ] Set the price, paid up front — section 9 recommends $4.99 as an announced
      launch price moving to $9.99, or $6.99 flat. Confirm availability in every
      territory you intend to sell in. No in-app purchases exist, so the pricing
      section is the only place this is configured.
- [ ] If a launch price is used, say so in the promotional text, which can be
      changed without a new build, and diarise the date it ends.
- [ ] Set the age rating (4+; the app has no objectionable content).
- [ ] Paste the review note from section 2 into App Review Notes.
- [ ] Confirm the export compliance answer: **no**, the app does not use
      non-exempt encryption (see section 4).
- [ ] Choose a signing team and archive with the Release configuration.

### Metadata that is already set

| Field | Value |
| --- | --- |
| Bundle identifier | `com.sergiiziborov.GopherForge` |
| Version | 1.0.0 (build 1) |
| Category | Developer Tools |
| Minimum iOS | 18 |
| Devices | iPhone and iPad |
| Copyright | © 2026 Serhii Ziborov |
