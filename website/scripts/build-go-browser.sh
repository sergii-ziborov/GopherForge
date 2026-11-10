#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GO_BROWSER_COMPILER="${GOPHERFORGE_GO:-go}"
GO_BROWSER_VERSION="$(GOTOOLCHAIN=local "$GO_BROWSER_COMPILER" env GOVERSION)"
if [[ "$GO_BROWSER_VERSION" != go1.27.* ]]; then
  echo "Browser planner requires Go 1.27.x. Set GOPHERFORGE_GO to its go executable (found $GO_BROWSER_VERSION)." >&2
  exit 1
fi
mkdir -p build
(cd toolchain && GOOS=wasip1 GOARCH=wasm GOTOOLCHAIN=local "$GO_BROWSER_COMPILER" build -trimpath -o ../build/planner.wasm .)
GOPHERFORGE_PLANNER_VERSION="$GO_BROWSER_VERSION" python3 scripts/prepare-go-browser.py
