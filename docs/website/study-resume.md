# Learning maps and study bookmarks

Updated 20 October 2026.

## Website

- Interview uses the same forest, branch, lesson row and progress-control styles as Learn Go. Twelve topics form three directions. Search, difficulty and study-status filters combine; filter state is shareable in the URL.
- Each map shows its last opened material, opens the corresponding branch and labels the row **Your saved place**. The home page offers **Continue learning** for the most recently used area.
- `gopherforge.study.v1` stores only schema version, last area, and one material ID / section ID per area. Opening a page saves its location; scrolling or following a section anchor updates the bookmark. Continue links to that section.
- Existing `gopherforge.learning.v1` completions and `gopherforge.interview.self-assessment.v1` marks retain their formats. Existing course visitors without a new bookmark can still resume the legacy last lesson.
- Browser reloads and new tabs use localStorage; same-tab custom events and cross-tab storage events refresh summaries. Unknown material IDs never become Continue links. Invalid data or blocked storage cannot prevent reading.
- No account or cloud synchronization. Native and web progress are independent. Clearing this site's browser data removes local progress. Privacy documentation describes all stored study information.

## Native application (1.1.5, build 40)

- Existing attempt history and interview self-assessments retain their formats.
- Trimming recent attempt history keeps each lesson's latest successful attempt and compiler-verification evidence, so continued practice cannot age a completion or badge out of storage.
- LearnProgress stores last lesson and last interview guide as separate versioned UserDefaults keys. Merely opening material never records a pass.
- Course Continue shows the last opened lesson title and opens that lesson. Without a bookmark it uses the existing first-unfinished-lesson fallback.
- Interview has a Continue row, understood / revisit counts and a saved-place label. The selected Course / Interview segment survives relaunch.
- Explicit lesson or tool launch destinations take precedence over the saved segment. Unknown saved IDs are ignored.
- App Store 1.1.4 (39) was confirmed Ready for Distribution before preparing 1.1.5. The new submission is recorded separately in the release receipt.

## Verification

Results and publication identifiers are recorded in the accompanying publication receipt. The web tests cover legacy progress, bookmark persistence, invalid data, blocked storage and complete topic coverage. Native tests cover independent bookmarks surviving a recreated progress/store instance without changing completion, invalid saved IDs, and UI navigation through Continue after relaunch.
