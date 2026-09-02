#!/usr/bin/env bash
set -euo pipefail

# Captures the App Store screenshots at the sizes Apple asks for.
#
# The listing needs a 6.9" iPhone set and a 13" iPad set. Both are produced by
# driving the real app with AppStoreScreenshotUITests and exporting what it
# attached, so the pictures in the listing are the app running rather than
# something drawn to look like it.
#
# The app is uninstalled before each run rather than the whole device erased.
# A simulator that has been used carries recent projects and course progress,
# and a listing screenshot showing yesterday's debris is the kind of thing
# nobody notices until it is public — but erasing the device brings back the
# first-run system banners, and one of those landed across the top of a
# screenshot here. Uninstalling takes the app's own data and leaves the system
# settled.
#
# The status bar carries the simulator's own clock. `simctl status_bar
# override` works on a booted device — checked — but does not survive into
# screenshots taken inside the test run, and Apple does not ask for 9:41.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

OUTPUT="$PROJECT_ROOT/docs/app-store/screenshots"
DERIVED="$PROJECT_ROOT/DerivedDataScreenshots"

# name-in-simctl : folder
DEVICES=(
  "iPhone 17 Pro Max:iphone-6.9"
  "iPad Pro 13-inch (M5):ipad-13"
)

find_udid() {
  xcrun simctl list devices available \
    | awk -v want="$1" '
        index($0, want " (") == 1 || index($0, "    " want " (") == 1 {
          for (i = 1; i <= NF; i++) {
            if ($i ~ /^\([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\)$/) {
              gsub(/[()]/, "", $i)
              print $i
              exit
            }
          }
        }' | head -1
}

for entry in "${DEVICES[@]}"; do
  name="${entry%%:*}"
  folder="${entry##*:}"
  udid="$(find_udid "$name")"

  if [[ -z "$udid" ]]; then
    echo "warning: no simulator named '$name' is installed; skipping $folder" >&2
    continue
  fi

  echo "Capturing $folder on $name ($udid)…"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" com.sergiiziborov.GopherForge >/dev/null 2>&1 || true
  # Long enough for a freshly booted device to finish posting whatever it
  # wanted to tell its owner about.
  sleep 20

  # Not Release: the scheme's test action builds the unit test target too, and
  # that target uses `@testable import`, which Release does not carry. The
  # screenshots are identical either way — nothing here compiles Go.
  xcodebuild -project "$PROJECT_ROOT/GopherForge.xcodeproj" \
    -scheme GopherForge \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$DERIVED" \
    -only-testing:GopherForgeUITests/AppStoreScreenshotUITests \
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
