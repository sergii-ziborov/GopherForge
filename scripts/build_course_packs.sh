#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--locked" ]; then
  exec python3 -c 'import fcntl,subprocess,sys; from pathlib import Path; Path("build").mkdir(exist_ok=True); f=open("build/course-pack.lock","a"); fcntl.flock(f,fcntl.LOCK_EX); sys.exit(subprocess.call(["bash","scripts/build_course_packs.sh","--locked"]))'
fi
if python3 scripts/course_pack_cache.py --check; then exit 0; fi
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
xcrun --sdk macosx swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx15.0" -D LESSON_CATALOG_EXPORT scripts/course_pack_export.swift \
 GopherForge/Learn/Lesson.swift GopherForge/Learn/GoCourseCatalog.swift \
 GopherForge/Learn/GoConcept.swift GopherForge/Learn/Units/*.swift \
 GopherForge/Learn/Units/More/*.swift GopherForge/Learn/Solutions/*.swift \
 GopherForge/Learn/Reading/*.swift GopherForge/Learn/Hints/*.swift \
 GopherForge/Learn/Presentation/LessonGuide.swift GopherForge/Learn/Interview/InterviewPrep.swift \
 GopherForge/Learn/Quiz/QuizQuestion.swift GopherForge/Learn/Quiz/QuizCatalog*.swift \
 GopherForge/Learn/Matching/MatchingDrill.swift GopherForge/Learn/Matching/MatchingDrillCatalog.swift \
 GopherForge/Learn/Matching/ReviewMatchCatalog*.swift GopherForge/Learn/SpotTheBug/SpotTheBugRound.swift \
 GopherForge/Learn/Interview/InterviewQuestion.swift \
 GopherForge/Learn/Downloads/CoursePackage.swift -o "$STAGING/export"
"$STAGING/export" "$PWD/GopherForge/Resources/ReadingLessons.json" "$STAGING/packs"
python3 scripts/course_pack_manifest.py "$STAGING/packs"

python3 scripts/course_pack_cache.py --stamp
