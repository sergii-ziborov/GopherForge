#!/usr/bin/env bash
set -euo pipefail

# Stages the bundled Go-on-Wasm toolchain into the app bundle at build time.
#
# The app never downloads compiler components at runtime. This script is the
# only place a toolchain enters the product, every artifact is pinned by
# SHA-256, and staging is atomic so a partial unpack can never be mistaken for
# a complete toolchain.
#
# Unlike the Rust sibling there is no public prebuilt release to point at yet:
# hosting the Go compiler itself in WebAssembly is this project's Gate A
# feasibility spike (docs/DEVICE-GATE.md). Until that spike produces a pinned
# artifact this script stages nothing and says so, and the app reports the
# toolchain as missing. Once one is pinned, every failure below is fatal: a
# placeholder must never reach the bundle.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_TAG="${GOPHERFORGE_TOOLCHAIN_TAG:-go-wasm-unpinned}"
TOOLCHAIN_ROOT="$PROJECT_ROOT/GopherForge/Resources/Toolchain"
VERSION_DIR="$TOOLCHAIN_ROOT/$TOOLCHAIN_TAG"
MARKER="$VERSION_DIR/.complete"

# Expected layout inside the staged directory:
#   gotool.wasm  - the WASI-hosted Go toolchain driver (GOOS=wasip1)
#   goroot/      - bundled GOROOT: standard library sources and export data
#   .complete    - written last, so a partial unpack is never mistaken for one
#
# There is no wasm_exec.js here on purpose. That bridge belongs to the js/wasm
# target and needs a JavaScript engine; this app has none. Both the toolchain
# and the programs it builds target wasip1 and run under WASI in the same
# interpreter, which Go has supported as a first-class port since 1.21.
if [[ -f "$MARKER" && -f "$VERSION_DIR/gotool.wasm" && -d "$VERSION_DIR/goroot" ]]; then
  exit 0
fi

if [[ -n "${GOPHERFORGE_ARTIFACT_CACHE:-}" ]]; then
  CACHE_DIR="$GOPHERFORGE_ARTIFACT_CACHE"
else
  USER_CACHE_ROOT="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || true)"
  if [[ -z "$USER_CACHE_ROOT" ]]; then
    USER_CACHE_ROOT="/tmp/gopherforge-cache-${UID}"
  fi
  CACHE_DIR="${USER_CACHE_ROOT%/}/com.sergiiziborov.GopherForge/$TOOLCHAIN_TAG"
fi

TOOLCHAIN_ARCHIVE="${GOPHERFORGE_TOOLCHAIN_ARCHIVE:-go-wasm-toolchain.tar.zst}"
TOOLCHAIN_URL="${GOPHERFORGE_TOOLCHAIN_URL:-}"
TOOLCHAIN_SHA="${GOPHERFORGE_TOOLCHAIN_SHA256:-}"

if [[ -z "$TOOLCHAIN_URL" || -z "$TOOLCHAIN_SHA" ]]; then
  cat >&2 <<'MESSAGE'
No pinned Go toolchain artifact is configured.

Hosting the Go compiler in WebAssembly is Gate A of this project and has not
produced a published artifact yet. Once the spike builds one, pin it here:

  export GOPHERFORGE_TOOLCHAIN_TAG=go1.27-wasm-1
  export GOPHERFORGE_TOOLCHAIN_URL=https://example.invalid/go-wasm-toolchain.tar.zst
  export GOPHERFORGE_TOOLCHAIN_SHA256=<sha256 of that archive>

The staged directory must contain gotool.wasm and goroot/, both cut from the
same Go release. gotool.wasm must be a wasip1 build: the app runs it under WASI
in the same interpreter it uses for the programs it builds.

Until then the app builds and runs with the bundled toolchain reported as
missing, which every compiler gate treats as a failure rather than a skip.
MESSAGE
  # An unconfigured toolchain is a known project state while Gate A is open,
  # so it does not fail the build. A configured but unverifiable one does:
  # everything below this point refuses rather than stages something unproven.
  exit 0
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

if [[ ! -f "$STAGING/gotool.wasm" || ! -d "$STAGING/goroot" ]]; then
  echo "Pinned toolchain archive has an unexpected layout" >&2
  echo "Expected gotool.wasm and goroot/ at the archive root" >&2
  exit 1
fi

echo "$TOOLCHAIN_TAG" > "$STAGING/.complete"
if [[ -e "$VERSION_DIR" ]]; then
  echo "Incomplete toolchain directory already exists: $VERSION_DIR" >&2
  echo "Remove that exact directory and rerun this script." >&2
  exit 1
fi
mv "$STAGING" "$VERSION_DIR"

echo "Bundled toolchain staged at $VERSION_DIR"
