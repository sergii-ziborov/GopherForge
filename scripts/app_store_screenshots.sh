#!/usr/bin/env bash
set -euo pipefail

# Captures the App Store screenshots at the sizes Apple asks for.
#
# The listing needs a 6.9" iPhone set and a 13" iPad set. Both are produced by
# driving the real app with AppStoreScreenshotUITests and exporting what it
# attached, so the pictures in the listing are the app running rather than
# something drawn to look like it.
#
# The simulators are created by this script and used for nothing else.
#
# Shared simulators were tried twice and carry whatever else has run on them. A
# capture came back with "GopherForge" running under a "< Crabrix" breadcrumb
# left by a sibling project, and another came back in dark mode because that is
# how the device had last been left. Uninstalling this app does not clear
# either, because neither belongs to this app. A device this script owns has
# nothing else on it to begin with.
#
# Appearance is set explicitly for the same reason: a simulator follows the
# Mac's own light/dark setting, so otherwise the listing's theme is decided by
# whatever the laptop happened to be set to that evening.
#
# Erasing brings back the first-run system banners, and one of those landed
# across the top of a screenshot too, so the settle below is long enough for
# them to appear and go before anything is captured.
#
# The status bar carries the simulator's own clock. `simctl status_bar
# override` works on a booted device — checked — but does not survive into
# screenshots taken inside the test run, and Apple does not ask for 9:41.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

OUTPUT="$PROJECT_ROOT/docs/app-store/screenshots"
DERIVED="$PROJECT_ROOT/DerivedDataScreenshots"

# device type : output folder : the name this script owns
DEVICES=(
  "iPhone 17 Pro Max:iphone-6.9:GopherForge Shots iPhone"
  "iPad Pro 13-inch (M5):ipad-13:GopherForge Shots iPad"
)

# The udid of a simulator this script owns, creating it the first time.
own_device() {
  local device_type="$1"
  local name="$2"
  local udid runtime

  udid="$(xcrun simctl list devices --json | python3 -c '
import json
import sys

want = sys.argv[1]
for entries in json.load(sys.stdin)["devices"].values():
    for entry in entries:
        if entry.get("name") == want and entry.get("isAvailable"):
            print(entry["udid"])
            raise SystemExit
' "$name")"

  if [[ -z "$udid" ]]; then
    runtime="$(xcrun simctl list runtimes --json | python3 -c '
import json
import sys

runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("isAvailable")
            and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]
if not runtimes:
    raise SystemExit(1)
# The newest iOS installed, which is what a listing should be shot on.
runtimes.sort(key=lambda r: [int(part) for part in r["version"].split(".")])
print(runtimes[-1]["identifier"])
')"
    udid="$(xcrun simctl create "$name" "$device_type" "$runtime")"
  fi

  printf '%s' "$udid"
}

for entry in "${DEVICES[@]}"; do
  device_type="${entry%%:*}"
  rest="${entry#*:}"
  folder="${rest%%:*}"
  own_name="${rest#*:}"

  if ! udid="$(own_device "$device_type" "$own_name")" || [[ -z "$udid" ]]; then
    echo "warning: could not find or create a '$device_type'; skipping $folder" >&2
    continue
  fi

  echo "Capturing $folder on $own_name ($udid)…"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl ui "$udid" appearance light >/dev/null 2>&1 || true
  # Long enough for a freshly erased device to finish telling its owner about
  # itself. Shorter than this and a banner lands on the first screenshot.
  sleep 60

  # A scheme of its own, in Release. The first screenshot is a real build
  # result, so the run compiles Go under the interpreter — which is unusably
  # slow unoptimised. The ordinary scheme cannot be built in Release because it
  # also builds the unit test target, and `@testable` needs a testability a
  # shipped binary should not carry.
  xcodebuild -project "$PROJECT_ROOT/GopherForge.xcodeproj" \
    -scheme GopherForgeScreenshots \
    -configuration Release \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$DERIVED" \
    test

  result="$(ls -td "$DERIVED"/Logs/Test/*.xcresult | head -1)"
  staging="$(mktemp -d)"
  xcrun xcresulttool export attachments --path "$result" --output-path "$staging" >/dev/null

  rm -rf "${OUTPUT:?}/$folder"
  mkdir -p "$OUTPUT/$folder"
  python3 - "$staging" "$OUTPUT/$folder" <<'PYTHON'
import json
import pathlib
import shutil
import sys

staging = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
manifest = json.loads((staging / "manifest.json").read_text())

# The attachment name is the screen; the exported file is a UUID. Walking the
# manifest is what puts a readable name back on the picture.
found = {}


def walk(node):
    if isinstance(node, dict):
        name = node.get("suggestedHumanReadableName")
        exported = node.get("exportedFileName")
        if name and exported:
            found[name.split("_")[0]] = exported
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)


walk(manifest)
if not found:
    raise SystemExit("no screenshots were attached; the capture run did not reach any screen")

for name, exported in sorted(found.items()):
    shutil.copy(staging / exported, destination / f"{name}.png")
    print(f"  {name}.png")
PYTHON
  rm -rf "$staging"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
done

echo
echo "Written to $OUTPUT"
echo "Sizes, which App Store Connect checks:"
for folder in "$OUTPUT"/*/; do
  [[ -d "$folder" ]] || continue
  first="$(ls "$folder"*.png 2>/dev/null | head -1)"
  [[ -n "$first" ]] || continue
  printf '  %-12s %s\n' "$(basename "$folder")" \
    "$(sips -g pixelWidth -g pixelHeight "$first" | awk '/pixel/ { printf "%s ", $2 }')"
done

# The README's pictures come out of the same run.
#
# They used to be taken by hand, which meant they aged out of sight: the Learn
# shot still showed 23 lessons long after the course had grown to 49, and the
# only way to notice was to look. Deriving them from the capture the listing
# needs anyway is what keeps the two in step.
README_SHOTS="$PROJECT_ROOT/docs/screenshots"
mkdir -p "$README_SHOTS"

# README name : device folder : capture
README_MAP=(
  "learn-path:ipad-13:03-course"
  "unit-path:ipad-13:07-unit"
  "run-output:ipad-13:01-compiler"
  "problems:ipad-13:08-problems"
  "workspace-tests:ipad-13:02-tests"
  "lab:ipad-13:05-lab"
  "my-projects:ipad-13:06-projects"
  "iphone-workspace:iphone-6.9:01-compiler"
)

echo
echo "README pictures, from the same captures:"
for entry in "${README_MAP[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  folder="${rest%%:*}"
  capture="${rest##*:}"
  source="$OUTPUT/$folder/$capture.png"

  if [[ ! -f "$source" ]]; then
    # Left alone rather than deleted: a half-updated README is worse than an
    # old one, and this says plainly which picture did not come through.
    echo "  warning: $folder/$capture.png is missing; $name.png left as it was" >&2
    continue
  fi

  cp "$source" "$README_SHOTS/$name.png"
  echo "  $name.png <- $folder/$capture.png"
done
