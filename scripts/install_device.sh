#!/usr/bin/env bash
set -euo pipefail

# Builds a signed GopherForge and installs it on the connected iPhone or iPad.
#
# Requires a device that is plugged in, unlocked, and has trusted this Mac.
# Everything else - team, profiles, entitlements - is already in project.yml.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null \
    | awk '$NF == "physical" && $(NF-1) == "connected" { print $(NF-4) }' \
    | head -1)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  cat >&2 <<'MESSAGE'
No connected device found.

Plug the iPhone or iPad in, unlock it, and tap Trust if asked. Then run this
script again, optionally passing a device identifier from:

  xcrun devicectl list devices
MESSAGE
  exit 1
fi

echo "Building for device $DEVICE_ID…"
xcodebuild -project "$PROJECT_ROOT/GopherForge.xcodeproj" \
  -scheme GopherForge \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$PROJECT_ROOT/DerivedDataDeviceSigned" \
  -allowProvisioningUpdates \
  build

APP="$PROJECT_ROOT/DerivedDataDeviceSigned/Build/Products/Debug-iphoneos/GopherForge.app"
echo "Installing $APP…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "Launching…"
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  com.sergiiziborov.GopherForge

echo "GopherForge is on the device."
