## When a successful build still produces a broken website

A Go service starts, its health endpoint responds, and its frontend homepage loads. A user then refreshes a nested React route and receives a not-found response. Another user requests a missing JavaScript file and receives HTML with a successful status. The deployment looks healthy from one endpoint while the actual application cannot reliably load. The mistake is treating a web interface as a loose directory rather than a versioned set of assets with routing contracts.

This practical guide is the **31 October 2026 archive edition**, first researched and published on **4 November 2026**. It develops an original embedded-asset fixture tested with Go 1.27.3. The fixture uses a tiny HTML document and script we wrote ourselves. It demonstrates delivery rules that can apply to a compiled React interface; it does not bundle someone else's React project or pretend that a static asset server executes frontend build tools.

The objective is a deployable artifact whose page routes, asset routes and API routes remain distinct. Build success is only one part of that objective. You also need to verify the files included in the artifact, the content type returned for each request, the treatment of missing resources and the relationship between browser caches and backend releases.

## Define the boundary between building and serving

A frontend build transforms source into deployable files. Serving those files is a different operation. The Go process needs the resulting HTML, scripts, styles and other declared resources, not the development server's transient state. If the build imports a font or library from a remote URL, embedding the local directory does not automatically remove that network dependency.

Treat the frontend output as an input to the Go build. Record which command creates it and fail the pipeline when required output is absent. A stale directory from a previous successful build can otherwise hide a broken current build. Use a clean output location or verify a build manifest against the artifact being packaged. The deployment should contain files produced from the same source revision that the release record describes.

This separation also improves local learning. A student can inspect the frontend output, inspect the embedded filesystem and compare requests without needing a remote host. A production team can apply the same checks in CI. Neither case requires a complicated framework to establish the basic invariant: the executable and the files it serves must describe the same application version. Once that relationship is explicit, routing failures become much easier to reproduce.

## Build, embed, route and verify

Use four stages. Build the frontend with pinned inputs. Embed the intended output directory. Route requests according to their role. Verify the resulting HTTP behavior against a finite request table. Each stage has an observable result, which makes the process easier to diagnose than a single deployment script that silently copies whatever files happen to exist.

The [embed package](https://pkg.go.dev/embed) describes the compile-time inclusion mechanism and pattern rules. Its important consequence for our workflow is that changing a source asset requires a new build of the consuming artifact. Embedding is not a live synchronization process. A successful running process will not discover an updated source file somewhere else on the developer's machine.

Verification should include a nested page route, a real asset, a missing asset, a real API endpoint, an unknown API endpoint and a disallowed method. The original lab uses `httptest` and starts no network listener. That keeps routing assertions reproducible while leaving deployment concerns, browser behavior and authentication to additional checks. A single homepage screenshot is useful for presentation, but it cannot establish that these distinct request classes behave correctly.

## Give the embedded filesystem an intentional root

The directory structure inside an embedded filesystem may differ from the URL structure you want to expose. Our fixture includes `ui/index.html` and `ui/assets/app.js`. The handler uses `fs.Sub` to make `ui` the logical root before looking up web files. That makes the mapping explicit instead of scattering prefix removal across unrelated handlers.

The [io/fs documentation](https://pkg.go.dev/io/fs) defines filesystem paths and the `Sub` operation. Use those APIs rather than treating every path as an operating-system filename. An embedded filesystem is useful partly because it gives the program a finite packaged set of files. It does not make every asset appropriate to publish. A credential accidentally included at build time is still included, even if the server process has no permission to read the original source directory later.

Review the packaging directory as a public surface. Keep source maps, development configuration and internal manifests only when their publication is intentional. Do not embed a repository root just to avoid choosing a smaller directory. For a project with several tools, define which tool owns the output and which step verifies it. A clear root reduces both accidental exposure and the common bug where the requested URL contains a directory prefix that the embedded lookup does not expect.

## Separate documents, assets and API responses

An application document can legitimately serve several client-side routes. A JavaScript asset must return JavaScript, and a missing API route must not quietly become an application document. The lab expresses these cases with separate ServeMux registrations. Only the known document routes return the HTML fixture; the asset subtree has its own handler; the API endpoint has its own response type.

For a large single-page application, you may need a broader document-route policy than the fixture's explicit allowlist. Make that policy deliberate. Checking whether a path has a file extension can be a useful supporting rule, but it is not a complete definition of which routes are documents. API prefixes, reserved paths and future route migrations also need consideration. Avoid a catch-all handler that returns the homepage for every unknown request.

The [net/http file-serving APIs](https://pkg.go.dev/net/http#FileServerFS) provide the serving primitives; they do not decide the product's route taxonomy. Keep that decision near the router and document it. A frontend router and a backend router must agree about which nested paths are page requests. The most productive debugging question is often not why React failed, but which handler actually answered the browser's request and what representation it returned.

## Make a missing script fail as a missing script

Our test table expects `/assets/app.js` to succeed and `/assets/missing.js` to return not found. It expects `/projects/42` to return a document, while `/missing.js` and `/api/missing` remain failures. This catches a particularly confusing class of bug: an asset request receives the homepage, and the browser later reports a syntax error at the first HTML character.

The fixture's essential route layout is small:

```go
mux.HandleFunc("GET /{$}", page)
mux.HandleFunc("GET /projects/{id}", page)
mux.HandleFunc("GET /assets/", assetHandler)
mux.HandleFunc("GET /api/status", statusHandler)
```

The download supplies the full handlers, embedded files and tests. The asset handler refuses directory URLs in this fixture, so a directory listing cannot accidentally become part of the public interface. It also uses an explicit revalidation-oriented cache policy rather than pretending that our teaching filename is a content-hashed immutable asset.

When diagnosing a real deployment, inspect the failed response before changing frontend code. Check its status, content type and first bytes. If the body is an HTML document, follow the backend routing decision. That observation can save hours of investigating a script bundle that was never actually returned.

## Cache policies must match filename guarantees

An immutable cache policy is useful when a resource URL changes whenever its content changes. That guarantee normally comes from the build's content hashing. Applying a long immutable policy to a stable filename can leave browsers using old code after the backend changes. Renaming a file to something that looks hashed is not enough; the build needs to maintain the content-to-name relationship.

HTML often needs a different strategy because it points to the current asset set. Our fixture uses `no-cache` so clients must revalidate stored responses before reuse. It does not implement a complete production validator strategy or claim a cache-hit benchmark. A production deployment should test its chosen ETag, modification-time or content-hash behavior alongside compression and the reverse proxy.

Think through a rolling release. A browser may receive one version's document and request its scripts after another instance begins answering traffic. If old asset names disappear immediately, an otherwise valid document can become unloadable. Retaining compatible versioned assets for the expected cache window or serving an atomic artifact consistently can address that risk. The correct choice depends on deployment topology. The invariant to test is that every script reference in a served document remains resolvable under the rollout policy you actually operate.

## Offline delivery is a dependency audit

An embedded directory can eliminate one category of external dependency, but a page can still call remote APIs, fetch a third-party stylesheet or load an image from another host. Inspect both the emitted files and the browser's network activity. A local homepage appearing once while a development server remains open does not establish offline operation.

Start from a clean browser context or an explicitly understood cache state. Record which resources the page requests and which application actions require a backend. Distinguish serving a local document, loading every required asset and completing a feature that needs remote data. These are separate acceptance criteria. A useful educational exercise is to replace a remote dependency with a small original local fixture, then verify the expected feature under the intended network conditions.

GopherForge's [application guide](/guide) explains its local development workflow and current boundaries. Use that guide to choose a compatible exercise rather than assuming that every desktop build tool or package exists inside every mobile environment. This article's Go handler tests run without a network listener, but browser execution and a full React-plus-backend integration remain additional checks. Describing those boundaries clearly makes an offline claim useful rather than merely reassuring.

## Test HTTP behavior without opening a port

`httptest.NewRecorder` and `httptest.NewRequest` let the lab call the handler directly. The request table checks status and representation for each route class. Another test checks that a HEAD request returns no body and that an unsupported POST to a document route receives method-not-allowed behavior. No live domain, credential or external API is required for these assertions.

This level of testing is effective because it sits at the contract boundary. It does not merely call an internal path-cleaning function and assume the router will use it correctly. The test exercises the same handler composition that receives a real request. It can catch the accidental broad fallback or route-registration change that would otherwise produce a successful HTML response for a missing asset.

After these deterministic tests pass, test the built artifact and the browser separately. Verify the actual packaged files, resource URLs, content types and deep-link refresh behavior. When a reverse proxy rewrites a prefix, repeat the request table through that public prefix. The [streaming I/O guide](/news/go-streaming-io-reader-eof-limits-json) is a useful companion for response handling, while the [shutdown guide](/news/go-http-graceful-shutdown-kubernetes) addresses the process lifecycle after the routing contract is correct.

## Use the same invariants with Gin

The framework can change without changing the questions. A Gin application still needs a defined static-files root, explicit API routes, a document fallback policy and meaningful failures for missing assets. Middleware order and catch-all behavior can alter which handler answers a request, so test the assembled router rather than reasoning about isolated registrations.

If a project already uses Gin, do not rewrite its whole routing layer merely to adopt embedded assets. Introduce the packaging boundary, connect the filesystem through the framework's supported APIs and reproduce the same request table. Keep middleware that performs authentication or records metrics aware of the route class. A missing script should not be counted as a successful application page just because a broad fallback produced a document.

The lab deliberately stays with the standard library so that the delivery contract is easy to inspect. It is an original teaching fixture, not a production Gin integration benchmark. For your application, add cases for authenticated paths, generated asset prefixes and any proxy mount point. Test one feature through the actual browser after the router checks pass. This keeps framework-specific details in their proper place while preserving the underlying contract across implementations.

## Turn the package into a reproducible learning exercise

[Download the engineering lab](/downloads/go-engineering-lab-20261104.zip) and run `go test ./embedlab`. Inspect the embedded `ui` directory before reading the handler. Predict which routes should succeed and which should fail, then change one registration and observe which test catches the mistake. Restore the correct version before building a deployable artifact.

For a frontend exercise, replace the original fixture with output from your own small React application. List every resource referenced by the resulting document. Add an assertion for a deep-link refresh and a missing generated script. Check the application after a clean build, not only while a frontend development process is serving files from a different directory. Preserve the original source and tests so that the transformation remains reviewable.

The [module and embedded-file lesson](/learn/modules.vendor-embed) connects this workflow to reproducible packaging. [Playground](/playground) and the [MCP guide](/guide/mcp) can help share a compatible example and its observed output, but editing a shared document does not prove the browser delivery contract. The evidence should include the artifact and request behavior. That makes the exercise useful to another developer who was not present when the successful screenshot was taken.

## A release check that follows the browser

Before releasing, verify the document, every referenced asset and at least one nested page route. Request a missing script and an unknown API endpoint deliberately. Confirm that the correct failures survive the reverse proxy and cache layer. Check the headers that matter to the browser rather than relying only on a process health endpoint.

Then review the artifact's ownership. Which build created the frontend files? Which source revision created the executable? Can a rolling deployment serve references to assets it no longer has? Are remote resources intentional and documented? These questions reveal deployment coupling that is invisible in a local happy-path run.

Save a small request table beside the packaging code. It should be short enough to run whenever routing or asset generation changes, and specific enough to catch a false HTML success. The result is a Go application whose web interface is part of the tested artifact. That is the foundation for a useful offline example, a reliable Gin deployment and a release that remains understandable after the original developer has moved on.
