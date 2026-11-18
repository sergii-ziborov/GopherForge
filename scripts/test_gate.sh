#!/usr/bin/env bash
set -euo pipefail
# Runs the unit tests the way a release is checked: in the Gate configuration.
#
# Gate is Release with testability, so WasmKit's interpreter is optimized. The
# end-to-end checks that run the bundled Go toolchain (debugger, offline
# preview) need that: an unoptimized Debug interpreter takes minutes per Go
# build, and those tests skip themselves in Debug rather than time out.
#
#   scripts/test_gate.sh                       # every unit test
#   scripts/test_gate.sh -only-testing:GopherForgeTests/GoDebuggerTests
#
# GOPHERFORGE_SIMULATOR selects a simulator UDID; otherwise the first available
# iPhone is used. The folder and line budget tests stay skipped here, as in
# earlier release gates, until the oversized files are split.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

SIMULATOR="${GOPHERFORGE_SIMULATOR:-}"
if [[ -z "$SIMULATOR" ]]; then
  SIMULATOR="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device["name"].startswith("iPhone") or "iPhone" in device.get("deviceTypeIdentifier", ""):
            print(device["udid"]); sys.exit()
')"
fi
if [[ -z "$SIMULATOR" ]]; then
  echo "error: no available iPhone simulator; set GOPHERFORGE_SIMULATOR" >&2
  exit 1
fi

SELECTION=("$@")
if [[ ${#SELECTION[@]} -eq 0 ]]; then
  SELECTION=(-only-testing:GopherForgeTests)
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
xcodebuild -project GopherForge.xcodeproj -scheme GopherForge -configuration Gate \
  -destination "platform=iOS Simulator,id=$SIMULATOR" \
  -derivedDataPath build/Gate -jobs 2 -parallel-testing-enabled NO \
  -collect-test-diagnostics never -resultBundlePath "build/Gate-$STAMP.xcresult" \
  "${SELECTION[@]}" \
  -skip-testing:GopherForgeTests/FolderBudgetTests/testNoFolderHoldsMoreThanTenSwiftFiles \
  -skip-testing:GopherForgeTests/ThirdPartyNoticesTests/testAppAndTeachingSourcesStayWithinTheLineBudget \
  CODE_SIGNING_ALLOWED=NO SWIFT_SUPPRESS_WARNINGS=NO test
