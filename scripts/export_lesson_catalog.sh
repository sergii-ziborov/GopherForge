#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cd "$PROJECT_ROOT"
xcrun swiftc -D LESSON_CATALOG_EXPORT "$SCRIPT_DIR/lesson_catalog_export.swift" \
  GopherForge/Learn/Lesson.swift GopherForge/Learn/GoCourseCatalog.swift \
  GopherForge/Learn/GoConcept.swift GopherForge/Learn/Units/*.swift \
  GopherForge/Learn/Units/More/*.swift GopherForge/Learn/Solutions/*.swift \
  GopherForge/Learn/Reading/*.swift \
  -o "$STAGING/export"
mkdir -p docs/website
"$STAGING/export" "$PROJECT_ROOT/GopherForge/Resources/ReadingLessons.json" > docs/website/lessons.json
printf 'Exported the actual course to docs/website/lessons.json\n'
