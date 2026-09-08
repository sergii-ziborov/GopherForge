# Release audit — 8 September 2026

## Observed state

- Submitted source is `aeb7516`; public repository
  `sergii-ziborov/GopherForge`, branch `main`.
- App Store Connect: GopherForge: Go Workbench, app `6809702319`, version 1.0,
  **Waiting for Review**. Cloud build **1.0.0 (4)** was submitted for listing
  version **1.0** at **20:57 Asia/Jerusalem**. Submission ID:
  `c9179887-1814-43ee-badc-fce5bbd1ac48`. Apple displayed "1 Item Submitted"
  and then Waiting for Review for this exact version and build.
- Local Xcode: 26.6 (`17F113`); local macOS: 27.0 beta (`26A5388g`).
  Xcode Apple Account is now signed in to the developer team. Distribution
  was built in Xcode Cloud; the local beta-OS archive was not uploaded.
- Crabrix build 6 is Waiting for Review. Its recorded successful cloud build
  used Xcode 26.6 on macOS 26.6.2. Its earlier failures included ITMS-90111,
  loose static-library resources, and incomplete App Group privacy reasons.
- GopherForge's saved review notes now describe the interpreter and CPU limit;
  the incorrect Sign-in required checkbox is off. Review contact was reused
  from the same owner’s existing Crabrix submission; the phone is not recorded
  in this public repository. Marketing/support URLs point to the live website.

## Changes

- Bundle Go standard-library archives as `goroot.zip`, retaining their bytes and
  licenses. They are data for the WASI interpreter, not native iOS libraries.
  Runtime extraction verifies SHA-256 and installs atomically into Caches.
  UI probing does not extract; compiler work prepares the library as needed.
- Both privacy manifests declare App Group UserDefaults reason `1C8F.1`.
  The host also retains its own settings reason `CA92.1`.
- Xcode Cloud must apply `ci_scripts/Release.xcconfig` to all targets via
  `XCODE_XCCONFIG_FILE`; this prevents WasmKit's warnings-as-errors conflict.
- Local release script refuses an explicitly selected Xcode-beta path.
  This path guard does not certify that arbitrary renamed Xcode/OS is stable.

## Xcode Cloud workflow configuration

1. Reuse existing workflow `App Store Release` in App Store Connect. For a
   genuinely new project, sign in to Xcode and use Integrate → Create Workflow.
2. Select released Xcode 26.6 and stable macOS, not a beta environment.
3. Add workflow environment variable `XCODE_XCCONFIG_FILE` with value
   `/Volumes/workspace/repository/ci_scripts/Release.xcconfig` (the post-clone
   check reports the correct checkout path if Apple's path changes).
4. Archive the GopherForge scheme in Release for iOS, with App Store Connect
   distribution. Cloud handles distribution signing. Do not set the
   GOPHERFORGE distribution variables globally: post-clone stages the pinned
   artifact once; the later app build reuses those verified resources.
5. Record Cloud run, commit, macOS/Xcode/SDK versions and uploaded build number.
   Verify Apple's processing/validation before selecting the build for review.
6. Finish pricing, privacy publication and rating; confirm screenshot sizes
   against the current screenshots directory. Record any outstanding device
   testing accurately. Apple's review outcome is external.

The pinned input is release `toolchain-go1.27.1-wasm-1`, SHA-256
`e260dc4d45c3b405ce0da94a4742ed5b02a60dfd6e5bbf0e025934044d714ebf`.

## Website

Lovable project: `c56d903d-f45d-4e68-818f-1c334f7e4420`.
Published and opened successfully: https://gopherforge.app and
https://gopherforge.lovable.app. Pages: home, privacy, support. The custom
domain is connected to Lovable and serves the site over valid HTTPS.
The product is proprietary even though its repository is public.

## Validation

- Fresh unsigned Release archive succeeded using the all-target xcconfig.
  Archive: `/tmp/GopherForge-packaged-check.xcarchive`; Xcode `17F113`, SDK
  `iphoneos26.5`, build-machine OS `26A5388g` (beta, not for upload).
- Inspected archived app and extension: both contain `1C8F.1`; no loose `.a`
  resources remain; bundled ZIP SHA-256 matches its sidecar.
- All 373 ZIP files match the pinned source bytes, including Go licenses.
- Three cold-cache compiler gates passed with the packaged library: repaired
  program compiles and runs (6.904 s), unused-variable diagnostic (0.558 s),
  package tests (13.568 s). Test execution: 21.030 s, zero failures.
- Two additional regression tests passed: corrupted ZIP rejected without
  installation, and library bytes restored after cache eviction.
- Shell syntax, plist validation and git diff whitespace checks passed.
- No physical-device test has been completed in this audit. Apple successfully
  processed cloud builds 1, 2 and 4. These three gates are targeted checks, not a
  full-suite rerun.
- Warning cleanup `aeb7516`: selects ZIPFoundation's throwing initializer,
  declares the lock-protected output stream Sendable, uses an immutable set,
  and explicitly discards optional workspace-save return values. Release build
  succeeds with none of the seven reported Swift warnings. Xcode still emits
  its informational AppIntents metadata-extraction warning. All 18 selected
  OutputLimit, GoVendorWriter, and WorkspaceAutosave tests passed (1.565 s).

References: [Apple required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype),
[Apple submission requirements](https://developer.apple.com/app-store/submitting/).

## Pricing and domain follow-up

- Saved App Store pricing: US base USD 6.99, Ukraine manual override USD 4.99;
  Ukraine verified by reopening the pricing page. Other territories use Apple localization.
- App Availability was still unset despite the ready review draft. Set it to
  all 175 countries/regions and future storefronts, effective after release;
  Apple confirms Available on App Release, including the US and Ukraine.
  Regional content and regulatory eligibility still apply.
- Published Lovable pricing, FAQ/support and five real Simulator screenshots.
- Connected `gopherforge.app` and `www.gopherforge.app` to the GopherForge project.
  DNS A resolves to `185.158.133.1`; HTTPS with this resolved address validates
  the certificate and serves the expected product, both prices and screenshot content.
  Initial NXDOMAIN has cleared: a normal HTTPS request now returns HTTP 200.
  The website reports submission/awaiting review, with no approval or download claim.

## Submission progress

- Workflow `App Store Release` (`50A4CEF5-A8D9-40BE-AB9C-C1A4A677880F`), main.
- Initial cloud builds 1 and 2 Succeeded using Xcode 26.6 (17F113), macOS
  Tahoe 26.6.2 (25G83). Build 2 was replaced with warning-fix build 4 before
  final submission.
- Marketing/support URLs saved as `https://gopherforge.app` and `/support`.
- Privacy URL `/privacy` saved; Data Not Collected published in App Store Connect.
- Developer Tools primary and Education secondary categories saved; licensed
  third-party-content rights saved. Existing age questionnaire checked through
  all seven steps; the existing 13+ override is retained. No mature, violent,
  medical, sexual, gambling or social-media content is declared; contests are
  Infrequent. Apple displays regional age equivalents and territorial exceptions.
- The initial draft passed Add for Review at 19:39. Its build 2 was removed
  from the draft and replaced with 1.0.0 (4). The new draft passed validation
  and was submitted at 20:57; Apple's detail page confirms Waiting for Review.
- Cloud temporarily showed its onboarding page, and Xcode's onboarding wizard
  reported success but then returned "Workflow does not exist" on Start Build.
  The original workflow reappeared with its existing ID and unchanged settings.
  It was started manually from App Store Connect: build **4**, ID
  `f8503a41-fe42-4934-9fc8-d81a24ee5b64`, commit `aeb7516`, Xcode 26.6 (17F113),
  macOS Tahoe 26.6.2 (25G83). Build started at 20:30 local time.
- Apple received build 4 at 20:34, processed it to Ready to Submit, and allowed
  its selection for review. Binary ID: `5ff1ec55-5e58-47a6-9b41-e5707b228bd8`.
  The Cloud dashboard intermittently reverted to onboarding, so no final
  dashboard warning count is claimed. The seven Swift diagnostics are absent
  from the local Release compilation of the same submitted commit.
- Website icons now derive from the actual native 1024-pixel app icon.
  Lovable publishing setting hides its badge on both public domains.
