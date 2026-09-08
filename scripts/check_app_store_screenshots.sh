#!/usr/bin/env bash
set -euo pipefail

# Checks the captured screenshots against what App Store Connect will accept.
#
# There is already a gate like this for the app icon, and it exists because an
# alpha channel is invisible locally and rejected on upload. Screenshots are
# held to the same rule — Apple restated it in July 2026 — and a rejection
# arrives hours after the submission rather than at capture time.
#
# Run after scripts/app_store_screenshots.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHOTS="$PROJECT_ROOT/docs/app-store/screenshots"

# folder : expected width : expected height
# Every size App Store Connect offers a slot for that this app can actually run
# on. Its deployment target is iOS 18, so the 5.5-inch, 4.7-inch and 4-inch
# iPhone slots and the 12.9-inch (2nd generation), 10.5-inch and 9.7-inch iPad
# slots stay empty on purpose: that is iPhone 8 and 2017 iPad hardware, capped
# at iOS 16 and 17, and a screenshot there advertises the app to devices that
# cannot install it.
#
# The dimensions are the ones Apple accepts for the slot, not the ones a
# plausible-sounding device happens to produce. The 6.1-inch slot takes
# 1170x2532 and refuses 1178x2556, which is what an iPhone 16 renders — that
# was caught by reading the slot rather than by trusting the device name.
EXPECTED=(
  "iphone-6.9:1320:2868"
  "iphone-6.5:1284:2778"
  "iphone-6.3:1206:2622"
  "iphone-6.1:1170:2532"
  "ipad-13:2064:2752"
  "ipad-11:1668:2420"
)

# What the listing itself uses, in order. The capture also writes 07-unit and
# 08-problems for the README, which are not part of the upload.
LISTING=(01-compiler 02-tests 03-course 04-lesson 05-lab 06-projects)

failures=0

fail() {
  echo "  ✗ $1" >&2
  failures=$((failures + 1))
}

for entry in "${EXPECTED[@]}"; do
  folder="${entry%%:*}"
  rest="${entry#*:}"
  want_width="${rest%%:*}"
  want_height="${rest##*:}"
  directory="$SHOTS/$folder"

  echo "$folder:"

  if [[ ! -d "$directory" ]]; then
    fail "missing entirely — run scripts/app_store_screenshots.sh"
    continue
  fi

  for name in "${LISTING[@]}"; do
    file="$directory/$name.png"

    if [[ ! -f "$file" ]]; then
      fail "$name.png is missing"
      continue
    fi

    width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"
    if [[ "$width" != "$want_width" || "$height" != "$want_height" ]]; then
      fail "$name.png is ${width}x${height}, expected ${want_width}x${want_height}"
    fi

    # `hasAlpha` is absent from the output for images that have none, so the
    # test is for the string rather than for a value.
    if sips -g hasAlpha "$file" | grep -q "hasAlpha: yes"; then
      fail "$name.png carries an alpha channel, which App Store Connect rejects"
    fi
  done

  count="$(ls "$directory"/*.png 2>/dev/null | wc -l | tr -d ' ')"
  echo "  ${#LISTING[@]} listing shots checked, $count files in the folder"
done

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures problem(s). Fix these before uploading." >&2
  exit 1
fi
echo "Screenshots are the right size, complete, and free of alpha."
