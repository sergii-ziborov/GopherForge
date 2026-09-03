# Installing a package

GopherForge compiles offline. Installing a package is the one moment it uses a
network, and this is what happens in that moment and why.

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

**Transitive dependencies are not resolved.** Adding module A vendors A and
adds A's requirement. It does not walk A's own `go.mod` and fetch what A
imports. If A imports B and B is not vendored, the build reports an unresolved
import; the compatibility report names it rather than failing obscurely. This
is the most common surprise, and it is why the listing says "a pure-Go module"
rather than promising that any module will work.

**`//go:embed` of non-Go assets does not survive.** Vendoring keeps `.go`
files, `go.mod` and the licence and notice files. Templates, images and other
embedded data are dropped, so a package built around `//go:embed templates/*`
will not find them. Supporting it properly also needs the build planner to
write an `embedcfg`, which it does not.

**Assembly and native source are dropped.** `.s` files and C or C++ sources are
filtered out of the archive. cgo is unsupported for the same underlying reason:
there is no native toolchain in the sandbox. Pure Go is the target, and that
covers most of the ecosystem worth using on a phone.

**`replace`, `exclude` and `retract` are parsed but not applied.** The `go.mod`
parser recognises them, and the build resolves imports from the paths actually
present rather than implementing module-resolution semantics. A project relying
on a `replace` directive is reported in the compatibility summary rather than
silently built against the wrong thing.

**`go.work` is not implemented.** A workspace is detected and its root module
opened; workspace semantics are not applied.

## The limit worth stating

The checksum database's response is a signed note over a transparency log. This
app reads the hashes out of it and does **not** verify the signature or the
Merkle proof. The trust is therefore TLS to `sum.golang.org` rather than the
log's own signature.

That is weaker than what `go` does on a laptop, and stronger than every "curl
this and run it" alternative. It is stated here, and in the app, rather than
left to be discovered.

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
