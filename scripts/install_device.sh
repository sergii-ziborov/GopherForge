#!/usr/bin/env bash
set -euo pipefail

# Builds a signed GopherForge and installs it on the connected iPhone or iPad.
#
# Requires a device that is plugged in, unlocked, and has trusted this Mac.
# Everything else - team, profiles, entitlements - is already in project.yml.
#
# Release by default, and that is not a preference. This app's whole job runs
# inside a Wasm interpreter, and an unoptimised WasmKit is slower by orders of
# magnitude - slow enough that a Debug build on a phone looks like a Build
# button that does nothing at all. Pass `debug` only when you need a debugger
# attached and are prepared for that.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

CONFIGURATION="Release"
DEVICE_ID=""
for argument in "$@"; do
  case "$argument" in
    debug|Debug) CONFIGURATION="Debug" ;;
    release|Release) CONFIGURATION="Release" ;;
    *) DEVICE_ID="$argument" ;;
  esac
done

if [[ -z "$DEVICE_ID" ]]; then
  # The identifier is found by its shape rather than by column number. Both
  # the name and the model hold spaces — "iPhone s", "iPhone 13 mini
  # (iPhone14,4)" — so counting fields from either end lands somewhere
  # different for every device, and the wrong column is a UUID-shaped nothing
  # that fails at install time with "device not found".
  DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null \
    | awk '$NF == "physical" && ($0 ~ / connected / || $0 ~ /available \(paired\)/) {
             for (i = 1; i <= NF; i++) {
               if ($i ~ /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/) {
                 print $i
                 exit
               }
             }
           }')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  cat >&2 <<'MESSAGE'
No connected device found.

Plug the iPhone or iPad in, unlock it, and tap Trust if asked. A device that
shows as "unavailable" is asleep, locked, or off this network; wake and unlock
it and try again. Then run this script, optionally passing an identifier from:

  xcrun devicectl list devices
MESSAGE
  exit 1
fi

echo "Building $CONFIGURATION for device $DEVICE_ID…"
xcodebuild -project "$PROJECT_ROOT/GopherForge.xcodeproj" \
  -scheme GopherForge \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$PROJECT_ROOT/DerivedDataDeviceSigned" \
  -allowProvisioningUpdates \
  build

APP="$PROJECT_ROOT/DerivedDataDeviceSigned/Build/Products/$CONFIGURATION-iphoneos/GopherForge.app"
echo "Installing $APP…"
xcrun devicectl device install app --timeout 900 --device "$DEVICE_ID" "$APP"

echo "Launching…"
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  com.sergiiziborov.GopherForge

echo "GopherForge is on the device, built $CONFIGURATION."
