#!/usr/bin/env bash
set -euo pipefail

# Capture the file navigator in the same UI test that checks its layout.
# These are README/QA images; App Store listing shots remain in
# scripts/app_store_screenshots.sh.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
WORK="$(mktemp -d)"
trap 'python3 -c "import shutil, sys; shutil.rmtree(sys.argv[1])" "$WORK"' EXIT

device_id() {
  local id runtime
  id="$(xcrun simctl list devices --json | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device.get("name") == sys.argv[1] and device.get("isAvailable"):
            print(device["udid"])
            raise SystemExit
 ' "$1")"
  if [[ -z "$id" ]]; then
    runtime="$(xcrun simctl list runtimes --json | python3 -c '
import json, sys
options = [r for r in json.load(sys.stdin)["runtimes"]
           if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]
options.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
if not options:
    raise SystemExit("No available iOS Simulator runtime")
print(options[-1]["identifier"])
')"
    id="$(xcrun simctl create "$1" "$2" "$runtime")"
  fi
  printf '%s' "$id"
}

capture() {
  local name="$1" label="$2" type="$3" id
  id="$(device_id "$name" "$type")"
  xcrun simctl boot "$id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$id" -b >/dev/null 2>&1
  xcrun simctl ui "$id" appearance light

  xcodebuild -project "$ROOT/GopherForge.xcodeproj" -scheme GopherForge \
    -configuration Debug -destination "platform=iOS Simulator,id=$id" \
    -derivedDataPath "$ROOT/DerivedDataUI" \
    -resultBundlePath "$WORK/$label.xcresult" \
    -parallel-testing-enabled NO \
    -only-testing:GopherForgeUITests/NavigatorFlowUITests/testNavigatorOccupiesOnePlaceForTheDevice \
    SWIFT_SUPPRESS_WARNINGS=NO test > "$WORK/$label.log" 2>&1 || {
      tail -80 "$WORK/$label.log" >&2
      return 1
    }
  xcrun xcresulttool export attachments --path "$WORK/$label.xcresult" \
    --output-path "$WORK/$label" >/dev/null
}

capture 'GopherForge Shots iPhone' iphone 'iPhone 17 Pro Max'
capture 'GopherForge Shots iPad' ipad 'iPad Pro 13-inch (M5)'

python3 - "$WORK" "$ROOT/docs/screenshots" <<'PY'
import json
from pathlib import Path
from shutil import copyfile
import sys

work, output = map(Path, sys.argv[1:])
expected = {
    "iphone": {"navigator-iphone-code", "navigator-iphone-files"},
    "ipad": {"navigator-ipad-persistent"},
}
for device, names in expected.items():
    source = work / device
    manifest = json.loads((source / "manifest.json").read_text())
    found = {}
    def visit(node):
        if isinstance(node, dict):
            name = node.get("suggestedHumanReadableName")
            exported = node.get("exportedFileName")
            if name and exported:
                found[name.split("_")[0]] = source / exported
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)
    visit(manifest)
    missing = names - found.keys()
    if missing:
        raise SystemExit(f"{device}: missing UI-test screenshots: {sorted(missing)}")
    for name in sorted(names):
        destination = output / f"{name}.png"
        copyfile(found[name], destination)
        print(destination)
PY
