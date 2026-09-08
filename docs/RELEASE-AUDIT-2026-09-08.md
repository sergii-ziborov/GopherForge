# Release audit — 8 September 2026

## Observed state

- GitHub source starts at `74a7fd7`; public repository
  `sergii-ziborov/GopherForge`, branch `main`.
- App Store Connect: GopherForge: Go Workbench, app `6809702319`, version 1.0,
  Prepare for Submission. No build selected. Xcode Cloud shows onboarding.
- Local Xcode: 26.6 (`17F113`); local macOS: 27.0 beta (`26A5388g`).
  Only an Apple Development signing identity is present; Xcode Apple Accounts
  is empty. A local archive is build evidence, not a distributable release.
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

## Xcode Cloud workflow to finish

1. Sign in to the developer Apple Account in Xcode; select GopherForge and
   Product → Xcode Cloud → Create Workflow. Reuse the GitHub repository above.
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
6. Finish pricing, privacy publication, rating and device tests;
   confirm screenshot sizes/order against the current screenshots directory.
   Only then submit the version. Apple's review outcome is external.

The pinned input is release `toolchain-go1.27.1-wasm-1`, SHA-256
`e260dc4d45c3b405ce0da94a4742ed5b02a60dfd6e5bbf0e025934044d714ebf`.

## Website

Lovable project: `c56d903d-f45d-4e68-818f-1c334f7e4420`.
Published and opened successfully: https://gopherforge.lovable.app .
Pages: home, privacy, support. Intended domain: `gopherforge.app`.
DNS currently returns NXDOMAIN; domain ownership/provider input is needed.
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
- No physical-device test or Apple distribution validation has been completed
  in this audit. These three gates are targeted checks, not a full-suite rerun.

References: [Apple required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype),
[Apple submission requirements](https://developer.apple.com/app-store/submitting/).
