#!/usr/bin/env bash
set -euo pipefail

# Makes sure a bundled Go-on-Wasm toolchain is staged before the app is built.
#
# The app never downloads compiler components at runtime. This script is the
# only place a toolchain enters the product, and it has exactly two ways to
# produce one:
#
#   1. build it here, from the Go release already installed on this Mac. That
#      takes about fifteen seconds and needs no network at all, because the
#      toolchain is stock Go cross-compiled to wasip1 with no patches;
#   2. unpack a pinned archive, verified by SHA-256, which is what a release
#      build should do so every shipped binary carries a known artifact.
#
# Staging is atomic either way, so a partial unpack can never be mistaken for a
# complete toolchain.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_ROOT="$PROJECT_ROOT/GopherForge/Resources/Toolchain"

# Expected layout inside a staged directory:
#   compile.wasm  - cmd/compile for wasip1/wasm
#   link.wasm     - cmd/link
#   vet.wasm      - cmd/vet, optional, driven by the unitchecker protocol
#   gofmt.wasm    - cmd/gofmt, optional
#   goroot/       - VERSION and the standard library's export data
#   .complete     - written last, so a partial unpack is never mistaken for one
#
# There is no wasm_exec.js here, and no `go` driver either. The first belongs to
# the js/wasm target and needs a JavaScript engine, which this app does not
# have. The second cannot work under WASI at all: `cmd/go` builds by spawning
# the compiler and the linker as child processes, and WASI has no way to spawn
# anything. The app therefore orders the build itself and calls the two tools
# directly — see GopherForge/Compiler/Planning and docs/TOOLCHAIN.md.

staged_toolchain() {
  local candidate
  for candidate in "$TOOLCHAIN_ROOT"/*/; do
    [[ -d "$candidate" ]] || continue
    if [[ -f "$candidate/.complete" && -f "$candidate/compile.wasm" \
       && -f "$candidate/link.wasm" && -d "$candidate/goroot" ]]; then
      echo "${candidate%/}"
      return 0
    fi
  done
  return 1
}

if EXISTING="$(staged_toolchain)"; then
  echo "Bundled toolchain already staged: $(basename "$EXISTING")"
  exit 0
fi

TOOLCHAIN_URL="${GOPHERFORGE_TOOLCHAIN_URL:-}"
TOOLCHAIN_SHA="${GOPHERFORGE_TOOLCHAIN_SHA256:-}"

# --- Path 1: build it here -------------------------------------------------

if [[ -z "$TOOLCHAIN_URL" || -z "$TOOLCHAIN_SHA" ]]; then
  GO="${GOPHERFORGE_GO:-$(command -v go || true)}"
  if [[ -n "$GO" && -x "$GO" && "${GOPHERFORGE_BUILD_TOOLCHAIN:-1}" == "1" ]]; then
    echo "No toolchain staged yet; building one from $("$GO" env GOVERSION)…"
    "$SCRIPT_DIR/build_toolchain.sh"
    exit 0
  fi

  cat >&2 <<'MESSAGE'
No bundled Go toolchain is staged, and none can be built here.

The toolchain is stock Go cross-compiled to wasip1 — no patches, no fork — so
building one takes about fifteen seconds on any machine with Go installed:

  scripts/build_toolchain.sh

For a release build, pin a published artifact instead so the shipped binary
carries a known one:

  export GOPHERFORGE_TOOLCHAIN_URL=https://example.invalid/go-wasm-toolchain.tar.zst
  export GOPHERFORGE_TOOLCHAIN_SHA256=<sha256 of that archive>

Until either happens the app still builds and runs, with the toolchain reported
as missing, which every compiler gate treats as a failure rather than a skip.
MESSAGE
  # A missing toolchain is a known project state, so it does not fail the
  # build. A configured but unverifiable one does: everything below this point
  # refuses rather than staging something unproven.
  exit 0
fi

# --- Path 2: unpack a pinned artifact --------------------------------------

TOOLCHAIN_TAG="${GOPHERFORGE_TOOLCHAIN_TAG:-go-wasm-pinned}"
TOOLCHAIN_ARCHIVE="${GOPHERFORGE_TOOLCHAIN_ARCHIVE:-go-wasm-toolchain.tar.zst}"
VERSION_DIR="$TOOLCHAIN_ROOT/$TOOLCHAIN_TAG"

if [[ -n "${GOPHERFORGE_ARTIFACT_CACHE:-}" ]]; then
  CACHE_DIR="$GOPHERFORGE_ARTIFACT_CACHE"
else
  USER_CACHE_ROOT="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || true)"
  if [[ -z "$USER_CACHE_ROOT" ]]; then
    USER_CACHE_ROOT="/tmp/gopherforge-cache-${UID}"
  fi
  CACHE_DIR="${USER_CACHE_ROOT%/}/com.sergiiziborov.GopherForge/$TOOLCHAIN_TAG"
fi

find_zstd() {
  if command -v zstd >/dev/null 2>&1; then
    command -v zstd
  elif [[ -x /opt/homebrew/bin/zstd ]]; then
    echo /opt/homebrew/bin/zstd
  elif [[ -x /usr/local/bin/zstd ]]; then
    echo /usr/local/bin/zstd
  else
    return 1
  fi
}

ZSTD_BIN="$(find_zstd || true)"
if [[ -z "$ZSTD_BIN" ]]; then
  echo "zstd is required to unpack the pinned Go toolchain: brew install zstd" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR" "$TOOLCHAIN_ROOT"

download_and_verify() {
  local name="$1"
  local url="$2"
  local expected="$3"
  local target="$CACHE_DIR/$name"
  if [[ ! -f "$target" ]] || [[ "$(shasum -a 256 "$target" | awk '{print $1}')" != "$expected" ]]; then
    echo "Downloading $name ($TOOLCHAIN_TAG)…"
    curl --fail --location --retry 3 --output "$target.partial" "$url"
    local actual
    actual="$(shasum -a 256 "$target.partial" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
      echo "SHA-256 mismatch for $name" >&2
      exit 1
    fi
    mv "$target.partial" "$target"
  fi
}

download_and_verify "$TOOLCHAIN_ARCHIVE" "$TOOLCHAIN_URL" "$TOOLCHAIN_SHA"

STAGING="$(mktemp -d "$TOOLCHAIN_ROOT/.stage.XXXXXX")"
cleanup() {
  if [[ -d "$STAGING" ]]; then
    rm -rf "$STAGING"
  fi
}
trap cleanup EXIT

"$ZSTD_BIN" -dc "$CACHE_DIR/$TOOLCHAIN_ARCHIVE" \
  | /usr/bin/tar -xf - -C "$STAGING" --strip-components 1

if [[ ! -f "$STAGING/compile.wasm" || ! -f "$STAGING/link.wasm" || ! -d "$STAGING/goroot" ]]; then
  echo "Pinned toolchain archive has an unexpected layout" >&2
  echo "Expected compile.wasm, link.wasm and goroot/ at the archive root" >&2
  exit 1
fi

echo "$TOOLCHAIN_TAG" > "$STAGING/.complete"
if [[ -e "$VERSION_DIR" ]]; then
  echo "Incomplete toolchain directory already exists: $VERSION_DIR" >&2
  echo "Remove that exact directory and rerun this script." >&2
  exit 1
fi
mv "$STAGING" "$VERSION_DIR"
trap - EXIT

echo "Bundled toolchain staged at $VERSION_DIR"
