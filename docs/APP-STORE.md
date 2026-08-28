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
> To try it: open the app, tap **Build**, and press **Run** on the sample
> project. No account or network is required.

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
| **3.1.1 In-app purchase** | The app sells nothing and contains no purchases. |
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

## 8. What still needs an App Store Connect account

These cannot be done from the source tree.

- [ ] Create the app record for `com.sergiiziborov.GopherForge`.
- [ ] Publish `PRIVACY.md` at a public URL and enter it as the privacy policy
      URL. **Required — a submission without one is rejected.**
- [ ] Provide a support URL.
- [ ] Answer the App Privacy questionnaire: *Data Not Collected* throughout.
- [ ] Upload screenshots for 6.9" and 6.5" iPhone and 13" iPad. The UI test
      suite drives every screen and is the easiest way to capture them
      consistently.
- [ ] Write the description and keywords. Suggested subtitle: *Learn and
      compile Go on your iPhone*.
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
