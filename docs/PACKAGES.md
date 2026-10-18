# Installing a package

The compiler runs locally. Package downloads and GitHub imports need a network;
subsequent builds use the source kept in the project.

This document describes the current source, including the upcoming 1.1.1
update. Public App Store version 1.1 still requires adding transitive modules
separately. Version 1.1.1 (33) is waiting for App Review; 1.1.2 (34) is in
private Internal QA TestFlight, as checked on 18 October 2026.

Add packages from inside an open project (Files sidebar or the workspace **⋯**
menu). The all-projects list and Settings do not install into a project they
do not have open.

## Why not just `go get`

`go get` is `cmd/go`, and `cmd/go` cannot run here — it builds by spawning the
compiler and the linker, and WASI cannot spawn (`docs/TOOLCHAIN.md`). So the
app does what `go mod vendor` would have left behind, directly.

## What an install does

1. **Resolve.** `proxy.golang.org/<module>/@v/list` for the versions, or
   `@latest` when a module has no tags. Module paths are case-folded for the
   proxy — `github.com/BurntSushi/toml` is fetched as
   `github.com/!burnt!sushi/toml` — and a path that fails validation never
   becomes a request.
2. **Look up.** deps.dev for the repository's stars, licence and OpenSSF
   Scorecard. This is decoration and it never blocks an install; if the service
   is unreachable the panel says there is no published metadata rather than
   inventing a number. There is no ratings service for Go modules, and the app
   does not pretend to be one.
3. **Fetch.** The module zip, with a size limit applied before unpacking and a
   file-count limit while unpacking. Every entry must sit under the module's own
   `path@version/` prefix; one that does not fails the install.
4. **Verify.** `sum.golang.org/lookup/<module>@<version>` gives the `h1:` hash
   the Go ecosystem records for that exact release. The app computes the same
   hash itself — `dirhash.Hash1`, reimplemented in `GoModuleHash` — and compares.
   **A mismatch is a refusal, not a warning**, and it happens before a single
   byte is written into the project.
5. **Vendor.** The source goes to `vendor/<module path>/`, `go.mod` gains or
   updates one `require` line, `go.sum` gains the two recorded lines, and
   `vendor/modules.txt` is rebuilt from what is actually there. Tests, testdata
   and hidden files are dropped, exactly as `go mod vendor` drops them; licences
   are kept, because vendoring is redistribution.

After that the dependency is source in the project. It is readable in the
editor, it travels with the project, and the compiler builds it like any other
package — `GoPackageGraph` gives a directory under `vendor/` the import path it
was published under, which is the whole point of vendoring.

## What a vendored module can and cannot be

Adding a dependency here is not `go get`, and the differences are worth stating
plainly rather than leaving someone to meet them halfway through a build.

**Missing imports use versions already declared in `go.mod`.** From 1.1.1,
build preparation downloads modules needed by unresolved imports, matching the
longest direct or indirect requirement path. GitHub import also prepares needed
packages. This does not recursively solve arbitrary module requirements or
implement Go's full module-version selection. A dependency absent from the
project's requirements may still need to be added. Preparation is bounded to
80 modules and keeps successful downloads when another module fails.

**`//go:embed` of non-Go assets does not survive.** Vendoring keeps `.go`
files, `go.mod` and the licence and notice files. Templates, images and other
embedded data are dropped, so a package built around `//go:embed templates/*`
will not find them. Supporting it properly also needs the build planner to
write an `embedcfg`, which it does not.

**Assembly and native source are dropped.** `.s` files and C or C++ sources are
filtered out of the archive. cgo is unsupported for the same underlying reason:
there is no native toolchain in the sandbox. Pure Go is the target;
compatibility still depends on the package.

**Module directives have limited support.** The download matcher considers
remote `replace` targets for a matching requirement. A replacement pointing to
a folder on another machine cannot be downloaded and is reported explicitly.
This is not a full implementation of `replace`, `exclude`, `retract` or Go's
module-resolution semantics.

**`go.work` is not implemented.** A workspace is detected and its root module
opened; workspace semantics are not applied.

## The limit worth stating

The checksum database's response is a signed note over a transparency log. This
app reads the hashes out of it and does **not** verify the signature or the
Merkle proof. The trust is therefore TLS to `sum.golang.org` rather than the
log's own signature.

This does not provide the transparency-log proof verification performed by
the standard Go tooling.

## Clearing downloaded packages

From 1.1.1, Settings → **Clear downloaded packages** removes downloaded
dependency source across saved user projects. User code and pinned dependency
versions remain; missing pins recorded only in an older vendor manifest are
preserved in `go.mod` before cleanup. Lessons and built-in Examples are excluded.

The next build downloads required packages again, so it needs network access.
This control is separate from clearing the compiler's build cache.

## What is checked, and how

Without a network:

- `GoModuleHashTests` pins the hash against a vector produced by the algorithm
  as Go specifies it — an implementation first checked against a real published
  `go.sum` entry. If that test passes, the app computes the same hash Go does.
- `GoModuleReferenceTests` covers path traversal, absolute paths, malformed
  versions, and a checksum response that talks about a different module.
- `GoVendorWriterTests` covers the whole effect on a project: one `require`
  line however many times you install, no leftovers from a previous version, a
  sorted and duplicate-free `go.sum`, and a `modules.txt` rebuilt from the
  directory rather than from memory.
- `BundledCompilerGateTests` compiles a hand-written vendored package with the
  real toolchain and runs it, and separately checks that an import which is
  neither local, vendored nor bundled is refused with a sentence a person can
  read.
