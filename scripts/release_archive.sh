#!/usr/bin/env bash
set -euo pipefail

# Cuts the archive that goes to App Store Connect, and exports a signed .ipa.
#
# Stable Xcode, not the beta: Apple takes App Store builds from a released
# Xcode, and the binary that ships should be the one that was tested.
#
# SWIFT_SUPPRESS_WARNINGS=NO is passed on the command line, and it has to be
# there rather than in project.yml. Xcode suppresses warnings in package
# dependencies while archiving; WasmKit's Package.swift asks for warnings to be
# treated as errors; swiftc refuses both at once and the archive fails with
# "conflicting options '-warnings-as-errors' and '-suppress-warnings'". Putting
# the setting in the project was tried and does nothing — package dependencies
# build as their own generated projects and do not inherit ours. A setting on
# the xcodebuild invocation reaches every target, including theirs.
#
# The ordinary build has never shown this, because only archiving suppresses
# those warnings. It fails at the one step that matters.
#
# This needs an Apple Distribution certificate in the keychain. A Mac that has
# only run device builds has an Apple Development one, which archives fine and
# cannot be exported for the store — the export step is where that shows up,
# with a message about no applicable signing identity. Creating the
# distribution certificate is done once, signed in to the developer account,
# in Xcode's Accounts settings.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ARCHIVE_ONLY=0
ARGS=()
for argument in "$@"; do
  case "$argument" in
    --archive-only) ARCHIVE_ONLY=1 ;;
    *) ARGS+=("$argument") ;;
  esac
done

OUT="${ARGS[0]:-$PROJECT_ROOT/build/release}"
ARCHIVE="$OUT/GopherForge.xcarchive"

if [[ "$DEVELOPER_DIR" == *Xcode-beta* ]]; then
  echo "warning: archiving with a beta Xcode; App Store builds want the released one" >&2
fi

# Checked before the build rather than after it. Without a distribution
# certificate the archive still succeeds and the export fails four minutes
# later, which reads like a broken script rather than a missing prerequisite.
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
  cat >&2 <<'MESSAGE'
error: no Apple Distribution certificate in the keychain.

Archiving would work; exporting for the App Store would not. The certificate
is created once, from the developer account:

  Xcode → Settings → Accounts → add the Apple ID → Manage Certificates →
  + → Apple Distribution

Then run this again. To cut an archive anyway — to check the build, not to
ship it — pass --archive-only.
MESSAGE
  [[ "${ARCHIVE_ONLY:-0}" == "1" ]] || exit 1
fi

mkdir -p "$OUT"
rm -rf "$ARCHIVE"

echo "Archiving with $("$DEVELOPER_DIR/usr/bin/xcodebuild" -version | head -1)…"
xcodebuild -project "$PROJECT_ROOT/GopherForge.xcodeproj" \
  -scheme GopherForge \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  SWIFT_SUPPRESS_WARNINGS=NO \
  archive

echo
printf 'Archive:  %s\n' "$ARCHIVE"
printf '  version   %s (%s)\n' \
  "$(plutil -extract ApplicationProperties.CFBundleShortVersionString raw "$ARCHIVE/Info.plist")" \
  "$(plutil -extract ApplicationProperties.CFBundleVersion raw "$ARCHIVE/Info.plist")"
printf '  signed by %s\n' \
  "$(plutil -extract ApplicationProperties.SigningIdentity raw "$ARCHIVE/Info.plist")"
printf '  commit    %s\n' "$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"
for provenance in "$PROJECT_ROOT/GopherForge/Resources/Toolchain"/*/toolchain-provenance.json; do
  [[ -f "$provenance" ]] || continue
  printf '  toolchain %s (%s)\n' \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["goVersion"])' "$provenance")" \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source"])' "$provenance")"
done

if [[ "$ARCHIVE_ONLY" == "1" ]]; then
  echo
  echo "Stopping here: --archive-only. Nothing was exported and nothing can be uploaded."
  exit 0
fi

echo
echo "Exporting for App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$PROJECT_ROOT/ExportOptions.plist" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates \
  SWIFT_SUPPRESS_WARNINGS=NO

echo
echo "Archive:  $ARCHIVE"
ls -1 "$OUT"/*.ipa 2>/dev/null | while read -r ipa; do
  printf 'IPA:      %s (%s)\n' "$ipa" "$(du -h "$ipa" | cut -f1)"
done


cat <<'NEXT'

Next, in App Store Connect:
  1. Upload the .ipa with Transporter, or Xcode's Organizer.
  2. Paste the listing text from docs/APP-STORE.md section 8.
  3. Work through the checklist in section 10 — privacy, DSA, price, rating.
NEXT
