# App Store listing audit

## Version 1.1.1 (33), 18 October 2026

Apple accepted submission `55221c50-655d-44e9-aa3d-32404b1f5996`.
Version 1.1.1, its custom product page, Header and Search Results assets are
`WAITING_FOR_REVIEW`. Build 33 is `VALID`, selected for the App Store version,
available in Internal QA TestFlight, and installed on the physical iPhone.
Release remains automatic after approval. The receipt is recorded in
[the build 33 record](../releases/1.1.1-build33.json).

Promotional Text, Description, What's New, Keywords, App Review notes and
TestFlight descriptions/testing notes reflect the shipped features and fixes.
The keyword field is 98 ASCII characters. Support, marketing, privacy and terms
links returned HTTP 200 with a normal browser user agent.

Both submitted pages contain ten fresh build 33 screenshots for each of seven
display groups: 140 images, with `00-code-build33.png` first in every group.
Header and Search placements are active on both pages. The separate, unsubmitted
optimization draft has twenty refreshed images and also starts with code.

Qualification passed conventional iPhone landscape/keyboard checks, iPad
rotation/keyboard checks, native closed-Duo rotation checks and six panel unit
checks. Expanded/laptop Duo postures were not rechecked because the Mac was
locked; existing Duo layout, navigation and keyboard handling were retained.
The Duo listing's last three images were captured through the existing Examples
route after automated dashboard scrolling did not reach that library.

## Historical audit and version 1.1 submission

Live version checked on 10 October; build 20 submission checked on 12 October 2026.
This records the English (US) listing for app `6809702319`; it is not an
instruction to submit a build for review.

| Field | Current state |
| --- | --- |
| Name | GopherForge: Go Workbench |
| Subtitle | Version 1.0.1: **Code, test & learn offline** (26 of 30 characters), confirmed in the live App Store Connect localization. |
| Categories | Developer Tools (primary), Education (secondary). |
| Description | Present in both versions; 1.0.1 leads with on-device build, test and run. |
| Keywords | `golang,compiler,programming,editor,goroutines,concurrency,backend,modules,packages,ide,tutorial,wasi` (100 bytes). |
| Promotional text | “Stock Go 1.27.1, on your device. Compile, vet, test and run with no cloud compiler — then learn Go idioms and concurrency judged by that same toolchain.” |
| Support URL | https://gopherforge.app/support |
| Marketing URL | https://gopherforge.app |
| Privacy policy URL | https://gopherforge.app/privacy |
| Price | Paid up front; US $6.99. No subscription or in-app unlock. |
| Availability | Available in 175 territories according to App Store Connect. Public lookup confirms version 1.0.1 in the US, Israel and Ukraine. |
| Screenshots | Ten iPhone 6.9-inch, ten iPhone 6.1-inch and ten iPad 13-inch images are attached to 1.0.1. All 30 are processed; each set starts with `00-code.png`. |
| Creative assets | `header.png` and `search-results.png` are approved. Their default product page header and App Store search results placements are both `ACTIVE`. |

Version 1.0.1 is **Ready for Sale** with build 13. Apple's public iTunes lookup
reports 1.0.1 and the US price of $6.99. The App Store web page shows the
category under the name, but App Store Connect confirms the 1.0.1 subtitle;
the web layout alone does not establish that the subtitle is missing. The
new version 1.1, build 20, is available in Internal QA TestFlight and was
submitted to App Review on 12 October 2026. It is `WAITING_FOR_REVIEW`,
with automatic `AFTER_APPROVAL` release.

## Version 1.1 submission

Version 1.1 (20) uses **Offline compiler & code editor** as its 30-character
subtitle. The 97-character keyword field is:
`golang,programming,learn,tutorial,goroutines,concurrency,backend,module,package,terminal,ide,wasi`.
It avoids repeating exact words already covered by the name and subtitle.
The description opens with an offline Go compiler and code editor for iPhone and
iPad, then explains compilation, lessons, Duo, privacy and limits. The 142-character
promotional text describes the benefits; it is not used as a keyword list.
All saved localization fields and the privacy policy URL were read back from Apple.

The original physical-iPhone recording is attached to the submitted version.
Its notes distinguish the earlier recording from the new 1.1 and Duo interface.
All 70 screenshots are assigned across seven display groups, with code first.
Three are new build 20 laptop captures; the other feature captures retain the
unchanged 1.1 lesson and compiler content. Outdated Open/Book captures were removed.
A new opaque 5244 × 2950 universal PNG passed processing and is used for both
Header and Search Results. The image and build entered Waiting for Review together.
Publication is recorded in [the build 20 receipt](../releases/1.1-publication20.json).
Pricing remains a one-time paid download.

Apple's [product page guidance](https://developer.apple.com/app-store/product-page/)
and [search guidance](https://developer.apple.com/app-store/search/) support the
field limits and relevant keyword selection. These changes do not establish an
increase in rankings or conversion; the observed traffic sample is too small.

An App Store preview video is optional and is separate from the screen
recording already sent for App Review. The listing does not need a second copy
of that review recording.

The App Store currently says the developer has not indicated accessibility
features. Declare only features verified against Apple's criteria across the
app's common tasks and each supported device; code identifiers alone do not
establish VoiceOver or Larger Text support.

The header and search creative placements are for App Store experiences on
iOS and iPadOS 27 or later. An active placement alone does not establish that
the browser displayed it. Version 1.1's universal image was verified as processed
and then waiting for review with the submitted version; public release still
requires Apple approval.


## 1.1.2 (36), submitted 19 October 2026

Description, promotional text, keywords, release notes and review instructions
now describe 92 teaching lessons in 15 units and 25 practical Around Go lessons.
Shell and deployment examples are explicitly learning material for the user's
own development environment. The original paid download model, title/subtitle,
support, privacy and terms links are retained.

The main version and Learn Go custom page are Waiting for Review with automatic
release after approval. Both have seven complete screenshot groups, code first;
two learning frames per group are newly captured from build 36. Header and Search
Results are active. See [the build 36 receipt](../releases/1.1.2-build36.json).

## 29 October 2026 — 1.3.2 (51)

Submitted and confirmed **WAITING_FOR_REVIEW**, automatically released after approval. The public version remains 1.3.1 (49). Metadata describes temporary capability-based Playground rooms, local-device execution, compatible Claude/Codex MCP clients and explicit revocable learning-progress snapshots. It distinguishes a pending AI request from a local Run, and the offline educational npm subset from a full Node runtime.

The six screenshot galleries contain 55 images, including twelve fresh native Playground/progress captures. Header and Search Results are ACTIVE. Privacy is published as Other User Content and Product Interaction, App Functionality, Data Not Linked to You; no tracking/account/username. [Submission](../releases/1.3.2-build51-submission.json) · [Assets](../releases/1.3.2-build51-assets.json) · [Metadata](metadata/1.3.2.en-US.json).
