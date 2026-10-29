# GopherForge search audit — 29 October 2026

Google Search Console accepted `https://gopherforge.app/sitemap.xml` with **439 discovered URLs**. The domain property already existed. The successful row and discovered count were read directly in the authenticated console, not inferred from HTTP delivery.

The historical coverage report, last updated **23 October**, showed **201 indexed / 64 excluded**: 45 not found, 10 alternate pages with proper canonical, 3 redirects and 6 crawled but not indexed. These totals predate the latest additions. The 45 not-found samples were mainly external documentation paths on the wrong host plus `/learn/$lesson`; the current public pages do not contain these local links. We did not redirect missing documentation to the homepage or claim that all exclusions were resolved.

The official live Rich Results Test initially reported four noncritical Article warnings for date-only `datePublished` and `dateModified`. Metadata now normalizes legacy day-precision editorial values to ISO timestamps with an explicit UTC offset; these normalized midnight values are **not exact historical publication times**. Visible editorial dates and content IDs remain unchanged. After publication Google detected three valid items and **no Article warnings**. The matching screenshots and result URL are attached.

All 439 sitemap pages were fetched again after deployment. Each returned HTTP 200, had a unique title and description, a matching self-canonical, one H1, no accidental noindex, parseable JSON-LD and an explicit document language. No missing image alt attributes were found. This checks presence/consistency, not editorial quality or rankings.

The native/website source icon remains unchanged. Browser favicon delivery dropped from 1,329,684 bytes to 8,060 bytes (64×64); an opaque 180×180 Apple touch icon was added. 35 web tests and the production build passed. Existing Next filesystem-tracing and Node module-type warnings remain nonfatal.

The replacement container retained the published-progress volume and restart policy. A disposable snapshot was created before replacement, read afterwards, checked for noindex headers, then revoked. The community feed was delivered into the replacement container. The local user Playground at port 3064 and native App Review submission were not changed.

Google accepted a specific indexing request for the new eMudhra article. This is not confirmation that it is indexed. Manual actions and security reports both said **No issues**. Core Web Vitals had insufficient field data; no passing performance score is claimed.

No accounts, tracking SDK, fabricated reviews, automated indexing spam or recurring monitor were added. Sitemap acceptance does not guarantee indexing, traffic or rich-result display.

## Final curriculum follow-up

A representative lesson’s official test found an incomplete nested `Course` entity (missing description and optional provider). Google’s course-list guidance describes instructor-led courses with a roster; this site provides open, self-directed learning without enrollment. The catalog now uses `CollectionPage`, with `LearningResource` for units and lesson relationships, instead of implying eligibility for that course-list feature. All **270 generated lesson/unit pages** were parsed and checked for the obsolete Course type. The final production image is `f3bba6f`; 15 representative HTTPS checks passed after replacement, the 439-URL sitemap is unchanged, and the lesson’s new official test shows **one valid BreadcrumbList, no invalid Course item**. The disposable shared snapshot again survived replacement and was then revoked.

The homepage’s official test detected one valid Software App item and one noncritical recommendation for `aggregateRating`. The US App Store lookup returned zero ratings. We did not fabricate an aggregate rating. That optional recommendation remains documented.

References: [Google course-list eligibility](https://developers.google.com/search/docs/appearance/structured-data/course), [clean article result](https://search.google.com/test/rich-results/result?id=XEtHUits55jUK4XsDkmK5Q), [clean lesson result](https://search.google.com/test/rich-results/result?id=XlCgslid98ep4vwfAPD16A).
