#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required: brew install xcodegen" >&2
  exit 1
fi

# The toolchain step is allowed to fail while Gate A is open: the project must
# still generate and build with the bundled compiler reported as missing.
"$SCRIPT_DIR/fetch_toolchain.sh" || echo "Continuing without a bundled Go toolchain (Gate A open)." >&2
xcodegen generate --spec "$PROJECT_ROOT/project.yml" --project "$PROJECT_ROOT"

echo "Generated $PROJECT_ROOT/GopherForge.xcodeproj"
