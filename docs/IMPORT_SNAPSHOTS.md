# Import snapshots

Audit implementation on `codex/audit-roadmap-20261028`; these changes are not yet in the public App Store build.

Import copies source into the app. It does not edit the selected folder in place and is not a Git clone. Keep the original checkout or archive for assets and history that the snapshot cannot represent.

GitHub import first resolves the requested branch/tag/default branch through the [GitHub commits API](https://docs.github.com/en/rest/commits/commits#list-commits), then downloads the archive using the full commit SHA. The requested ref, actual commit and compressed archive SHA-256 are saved with the snapshot. An old import without a commit is not automatically repaired using today's moving branch: re-import it as a separate project and compare your edits.

UTF-8 source, testdata, vendor source, CI configuration and JS/JSX/TS/TSX browser files are retained within the snapshot budget. This does not establish that every retained file's runtime semantics are supported. Binary assets, invalid UTF-8, oversized files and unsupported types are omitted with reasons. `.git`, node_modules, `.next` and app backup directories are excluded. Links are not followed. Archive paths that escape their root are rejected or inventoried; duplicate regular-file paths are refused.

Project → **Import details** lists the import scope, original retained paths, omission totals by reason and the first 2,000 omitted paths. Totals include further omissions. If a nested module was selected, the report says that other checkout folders were outside the selected scope. Large local folders fail rather than silently exceeding their file budget.

**Export contains the current text snapshot and your edits. It cannot recreate omitted assets or Git history.** A partial import is labelled in the project menu and export action. App document export also preserves the inventory. A full worktree with opaque assets and edit-in-place is a separate roadmap package, not an existing feature.

Budgets: 2,000 retained text files; 512 KiB per file; existing editor line limits. Local folder reads also have a 24 MiB aggregate read budget and a 50,000-entry traversal ceiling. GitHub compressed downloads are capped at 64 MiB; tar expansion at 32 MiB. Reaching a budget is not proof of an invalid Go project.
