#!/usr/bin/env bash
set -euo pipefail

# Refuses to build an app whose icon App Store Connect would reject.
#
# An icon with an alpha channel fails at upload — after the archive, after the
# signing, after the wait — with a message that does not say which file. The
# channel comes back easily, because every image editor writes RGBA by default
# and the icon looks identical either way. Better to hear about it here.
#
# A build phase rather than a unit test because the file lives inside an asset
# catalogue, where nothing can reference it individually, and because this is a
# fact about the artifact rather than about the code.

ICON="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}/GopherForge/Resources/Assets.xcassets/AppIcon.appiconset/GopherForgeIcon-1024.png"

if [[ ! -f "$ICON" ]]; then
  echo "error: the app icon is missing at $ICON" >&2
  exit 1
fi

properties="$(sips -g hasAlpha -g pixelWidth -g pixelHeight "$ICON" 2>/dev/null)"
alpha="$(awk '/hasAlpha:/ { print $2 }' <<< "$properties")"
width="$(awk '/pixelWidth:/ { print $2 }' <<< "$properties")"
height="$(awk '/pixelHeight:/ { print $2 }' <<< "$properties")"

if [[ "$alpha" == "yes" ]]; then
  echo "error: $ICON has an alpha channel." >&2
  echo "App Store Connect rejects transparent icons at upload. Flatten it onto" >&2
  echo "its own background colour and rebuild." >&2
  exit 1
fi

if [[ "$width" != "$height" ]]; then
  echo "error: the app icon is ${width}x${height}; it must be square." >&2
  exit 1
fi

if [[ "$width" -lt 1024 ]]; then
  echo "error: the app icon is ${width}px; the marketing icon must be at least 1024." >&2
  exit 1
fi
