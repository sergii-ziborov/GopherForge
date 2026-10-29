# Direct web preview — 28 October 2026

Native 1.3.0 build 48, source `fbc0c69`: uploaded, VALID, available in Internal QA TestFlight and WAITING_FOR_REVIEW. See the build-48 release receipts.

The reported React + Gin Output showed only successful `httptest` route checks.
The frontend had not been built, and the old build instructions were visible
only when there was no Go result. Output now keeps a **Build & Preview** card
above the result whenever an offline recipe has missing or stale assets. It
uses the terminal's existing bounded install/build pipeline, reports failures
in Output, preserves unsent terminal input, and rejects changed project
ownership before proceeding from installation to the build.

The embedded viewer has full-screen, reload and sharing actions. Static sites
can open their actual loopback address in the default browser or share that
address. The UI explains its device-only lifetime and possible iOS suspension.
Both preview types can share the project's `.tar.gz` snapshot. Isolated React
origins remain inside the app's configured WebKit viewer; they are not exposed
to Safari and do not gain network access. No public publishing service or
cross-device live URL is claimed. Browser session state is not in the archive.

## Verification

- `build/audit47/preview48-gate.xcresult`: 21 passed, no failures. Real React
  rendering, offline network rejection, current-buffer build and failure paths.
- `build/audit47/preview48-final.xcresult`: 45 passed, no failures. Includes the
  reported sequence (Go Run before frontend build), full-screen preview,
  static-site browser/share menu, and library restoration/location regressions.
- The UI flows are in their own `SitePreviewFlowUITests.swift`; the pre-existing
  large workspace UI suite was not enlarged.
- `build/audit47/web-guide-preview48-tests.log`: 27 web checks passed. Guide copy
  explicitly identifies these controls as upcoming until build 48 is released.
- Screenshots exported under `build/audit47/preview48-final-attachments/` show
  the post-Go-run build card, real rendered React and static preview actions.

These are focused gates, not a claim that the complete test suite or all 18
audit packages have passed. The final ownership guard was added after the
45-check gate; all five terminal/build ownership checks then passed in
`build/audit47/preview48-owner-final.xcresult`. The isolated physical Files A/B
switch/edit/process-relaunch flow also passed; see `2026-10-28-physical-files.json`.
