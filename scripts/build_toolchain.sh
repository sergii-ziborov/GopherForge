#!/usr/bin/env bash
set -euo pipefail

# Builds the bundled Go-on-Wasm toolchain from a Go installation on this Mac.
#
# This is Gate A, and it turns out to need no patched Go at all. `cmd/compile`,
# `cmd/link`, `cmd/vet` and `cmd/gofmt` all cross-compile to `wasip1/wasm` from
# a stock release, and all four run under WasmKit. What upstream cannot do is
# `cmd/go` itself: it builds by spawning the compiler and the linker as child
# processes, and WASI has no way to spawn anything. So the app does not bundle
# `cmd/go`. It works out the package order itself and calls the two tools
# directly — see GopherForge/Compiler/Planning.
#
# The consequence worth stating: this artifact tracks Go releases without a
# fork. A new Go is a re-run of this script, not a rebase.
#
# Output layout, which GoToolchainLocator reads and fetch_toolchain.sh stages:
#
#   <out>/compile.wasm            cmd/compile for wasip1/wasm
#   <out>/link.wasm               cmd/link
#   <out>/vet.wasm                cmd/vet, driven by the unitchecker protocol
#   <out>/gofmt.wasm              cmd/gofmt
#   <out>/goroot/VERSION          the release these were cut from
#   <out>/goroot/pkg/wasip1_wasm/ standard-library export data, one .a per package
#   <out>/manifest.txt            every staged import path, and the sizes
#   <out>/.complete               written last

usage() {
  cat >&2 <<'MESSAGE'
usage: scripts/build_toolchain.sh [output-directory]

Builds the wasip1 Go toolchain the app bundles. Requires a Go installation
whose release the artifact will carry; nothing is downloaded.

  GOPHERFORGE_GO   go binary to build with (default: whatever is on PATH)

The default output is GopherForge/Resources/Toolchain/go<version>-wasm-1, which
is where the app looks, so a plain run makes the next build a working one.
MESSAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GO="${GOPHERFORGE_GO:-$(command -v go || true)}"

if [[ -z "$GO" || ! -x "$GO" ]]; then
  echo "error: no go binary found. Install Go, or set GOPHERFORGE_GO." >&2
  exit 1
fi

GO_VERSION="$("$GO" env GOVERSION)"
if [[ -z "$GO_VERSION" ]]; then
  echo "error: '$GO env GOVERSION' said nothing; is that a Go installation?" >&2
  exit 1
fi

TAG="${GOPHERFORGE_TOOLCHAIN_TAG:-${GO_VERSION}-wasm-1}"
OUT="${1:-$PROJECT_ROOT/GopherForge/Resources/Toolchain/$TAG}"
STAGING="$OUT.staging.$$"

echo "Building the GopherForge toolchain from $GO_VERSION"
echo "  go:     $GO"
echo "  output: $OUT"

cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

rm -rf "$STAGING"
mkdir -p "$STAGING/goroot/pkg/wasip1_wasm"

export GOOS=wasip1
export GOARCH=wasm
# The toolchain must be the one that was asked for. A build that silently
# downloaded a different Go would carry a version the artifact does not match.
export GOTOOLCHAIN=local
export CGO_ENABLED=0

echo "==> cross-compiling the tools"
for tool in compile link vet gofmt; do
  printf '    cmd/%-8s' "$tool"
  "$GO" build -trimpath -o "$STAGING/$tool.wasm" "cmd/$tool"
  printf '%8s\n' "$(du -h "$STAGING/$tool.wasm" | cut -f1)"
done

echo "==> compiling the standard library for wasip1/wasm"
"$GO" build -o /dev/null std

# `std` deliberately excludes the test-only packages, and a test binary cannot
# link without them, so they are asked for by name.
echo "==> collecting export data"
LIST="$STAGING/std.list"
"$GO" list -deps -export -f '{{if .Export}}{{.ImportPath}}	{{.Export}}{{end}}' \
  std testing/internal/testdeps testing/quick > "$LIST"

count=0
while IFS=$'\t' read -r import_path export_file; do
  [[ -n "$import_path" && -n "$export_file" ]] || continue
  destination="$STAGING/goroot/pkg/wasip1_wasm/${import_path}.a"
  [[ -f "$destination" ]] && continue
  mkdir -p "$(dirname "$destination")"
  cp "$export_file" "$destination"
  count=$((count + 1))
done < "$LIST"
echo "    $count packages"

if [[ "$count" -eq 0 ]]; then
  echo "error: no export data was collected; refusing to stage an empty GOROOT." >&2
  exit 1
fi

echo "$GO_VERSION" > "$STAGING/goroot/VERSION"

# The BSD 3-Clause licence requires the copyright notice and disclaimer to be
# reproduced with a binary redistribution, and these wasm files are exactly
# that. Staging them here means the notice travels inside the app bundle
# rather than only being claimed in a document.
# Some distributions keep these beside GOROOT rather than inside it — Homebrew
# puts LICENSE one level up — so both places are searched before giving up.
GOROOT_SOURCE="$("$GO" env GOROOT)"
for notice in LICENSE PATENTS; do
  found=""
  for candidate in "$GOROOT_SOURCE/$notice" "$GOROOT_SOURCE/../$notice"; do
    if [[ -f "$candidate" ]]; then
      found="$candidate"
      break
    fi
  done
  if [[ -z "$found" ]]; then
    echo "error: $notice not found near $GOROOT_SOURCE." >&2
    echo "Refusing to stage a redistribution of Go without its licence." >&2
    exit 1
  fi
  cp "$found" "$STAGING/goroot/$notice"
done
{
  echo "# GopherForge bundled toolchain"
  echo "version	$GO_VERSION"
  echo "tag	$TAG"
  echo "target	wasip1/wasm"
  for tool in compile link vet gofmt; do
    echo "tool	$tool.wasm	$(wc -c < "$STAGING/$tool.wasm" | tr -d ' ')"
  done
  cut -f1 "$LIST" | sort -u | sed 's/^/package	/'
} > "$STAGING/manifest.txt"
rm -f "$LIST"

# Written last: GoToolchainLocator treats its absence as "not a toolchain", so
# an interrupted build can never be mistaken for a complete one.
touch "$STAGING/.complete"

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
mv "$STAGING" "$OUT"
trap - EXIT

echo "==> done"
echo "    $(du -sh "$OUT" | cut -f1) at $OUT"
echo
echo "The app finds this on its own. Build and run, and the Build tab will"
echo "report the bundled compiler instead of a missing one."
