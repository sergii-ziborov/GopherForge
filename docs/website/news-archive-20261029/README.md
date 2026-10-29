# News archive image fix and progressive pagination

29 October 2026. Sixteen cards requested nonexistent `-small.webp` derivatives.
The original 101 article images were intact. Archive cards now use the declared
original asset URLs, eliminating filename guessing for current and future posts.

Nine cards render in server HTML. IntersectionObserver reveals the next nine
near the end, with a finite end at all 33 articles. The Show more link supports
manual activation and works as normal navigation without JavaScript. Its
keyboard activation focuses the first new title. Numbered archive links use
native navigation so a previous long scroll cannot immediately trigger extra
loads on a new page. Four static pages have distinct self-canonicals,
CollectionPage lists and sitemap entries. Only summaries cross the client
boundary; complete article bodies remain on the server.

See checks.json, image-audit-before.json and local/live-verification.json.
Image responses were compared to repository originals by SHA-256. The original
asset inventory audit is read-only. Mobile width 390 has no document overflow.
No app binary, user data, accounts or storage settings changed.
