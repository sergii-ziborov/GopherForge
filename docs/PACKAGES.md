# Installing a package

The compiler runs locally. Package downloads and GitHub imports need a network;
subsequent builds use the source kept in the project.

This document describes the package implementation shared by the public
1.1.1 (33) release and the public 1.1.2 (36), checked on 19 October 2026.
The public 1.1 release previously required adding transitive modules separately.
The architecture/course work for 1.1.3 is on a separate development branch;
it does not change the archive budgets below.

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

## Archive budgets

The app inspects a module ZIP before installing it. These limits are enforced
by GopherForge, not by the Go language or the upstream module author.

| Budget | Current value | What is counted |
| --- | ---: | --- |
| Files per module archive | **4,000** | All non-directory ZIP entries, before vendoring or platform filtering |
| Downloaded ZIP | **96 MiB** | Compressed response bytes; checked by the bounded download |
| Uncompressed module | **512 MiB** | Sum of uncompressed file sizes declared in the archive; extraction also checks actual sizes |
| Automatic dependency preparation | **80 modules per pass** | Modules prepared for missing imports, using requirements already declared in `go.mod` |

A MiB is 1,048,576 bytes. Directories do not count toward the 4,000-file budget,
but tests, testdata, documentation, licences and sources for other operating
systems do. The file-count check happens before any contents are decompressed,
before checksum verification and before unused/platform-specific files are
removed. A module can therefore exceed the limit even when a single imported
package would eventually keep only a small part of it. All four budgets apply
independently; a small ZIP can still contain too many files.

### Example: modernc.org/libc

`modernc.org/libc@v1.75.3` has **4,168 non-directory archive entries**. This
exceeds the 4,000-file budget, so that version is rejected during dependency
preparation. The reported failure occurs before the Go compiler runs; it is
not a Go syntax error and is not evidence that device storage is full.

Retrying the same version fetches the same archive and reaches the same limit.
Choose another compatible version or a smaller dependency only if the project's
requirements allow it, or build the project in a desktop Go environment.
Successful downloading and checksum matching alone do not establish that a
module can compile or run in WASI. This example does not certify Memos, SQLite
or all of their transitive dependencies as supported.

The upstream ZIP directory was checked on 19 October 2026 without unpacking
its source; see the [Go module proxy archive](https://proxy.golang.org/modernc.org/libc/@v/v1.75.3.zip).

### Memory handling for large modules

Above **160 MiB uncompressed**, the implementation hashes entries one at a time
rather than retaining the whole unpacked archive. It then selects WASI-relevant
Go source and licence metadata. When relevant Go source exceeds **48 MiB** and
the imported package is known, it narrows retention to that package and its
in-module import closure. The 48 MiB value is a selection trigger, **not** a
promise that every resulting project stays below 48 MiB. Streaming and source
selection do not bypass the earlier 4,000-file or 512 MiB archive checks.

The archive cap bounds metadata, extraction and checksum work on a mobile
device. It remains in place. Raising it should be evaluated separately with
representative module archives and measured device memory, cancellation and
extraction behavior; a slightly larger file count alone does not demonstrate
full package compatibility.

Sources of truth: [GoModuleArchive.swift](../GopherForge/Packages/GoModuleArchive.swift),
[GoModuleProxyClient.swift](../GopherForge/Packages/Network/GoModuleProxyClient.swift),
and [GoDependencyPreparer.swift](../GopherForge/Packages/GoDependencyPreparer.swift).

## Checksum verification boundary

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
