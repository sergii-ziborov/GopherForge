# Offline React frontend: educational mode

This experiment targets the next build after submitted **1.2.0 (45)**. It is a
local browser build tool, not an installation of Node.js, npm or Bun for iOS.
The project stays on device. No cloud build or package registry is used at runtime.

<img src="examples/offline-frontend/fullscreen.png" width="330" alt="Native iOS screenshot of the offline React study board, with a task form, filters and local state">

[Embedded Output preview](examples/offline-frontend/output.png).

## Try the study board

1. Open Examples → Offline frontend → **React + Gin study board**.
2. Open the example in the workspace and select Terminal.
3. Run `frontend packages` to inspect the bundled versions.
4. Run `npm install --offline`, then `npm run build`.
5. Select Output and open the isolated preview, optionally full screen.
6. Add a task, toggle completion and switch filters. The topic list comes from
   the project's local `web/api/summary.json` fixture.
7. Edit `web/src/model.ts`, `TaskRow.tsx`, `main.tsx` or `style.css`; rebuild.

Source changes invalidate the old preview. They do not silently present old
generated JavaScript as current. Source, the offline lock and generated output
are autosaved with the project. Browser state is temporary and resets when a
preview is recreated; it is not the project's saved learning progress.

## Commands

| Command | Meaning |
| --- | --- |
| `frontend packages` | List the fixed bundled browser catalog |
| `frontend install` | Validate package requests and write the offline lock |
| `npm install --offline` / `bun install --offline` | Same educational install |
| `npm ci --offline` / `bun install --frozen-lockfile` | Require the existing lock to match |
| `frontend build` | Bundle from the declarative recipe inside WASI |
| `npm run build` / `bun run build` | Build only when the package script is `gopherforge build` |
| `frontend preview` | Check freshness and expose the preview in Output |
| `npm run preview` / `bun run preview` | Preview only when the package script is `gopherforge preview` |
| `npm --version` / `bun --version` | Explain this compatibility mode; no invented runtime version |

There is no general shell, lifecycle hook execution or subprocess support.
Other npm/Bun commands report that the full runtime is unavailable.

## Project files

`package.json`:

```json
{
  "private": true,
  "scripts": {
    "build": "gopherforge build",
    "preview": "gopherforge preview"
  },
  "dependencies": {"react": "19.3.1", "react-dom": "19.3.1"}
}
```

`gopherforge.frontend.json` is data, never executable configuration:

```json
{
  "entry": "web/src/main.tsx",
  "html": "web/index.html",
  "output": "web/dist",
  "minify": true
}
```

The HTML template needs `<!-- gopherforge:assets -->` where the generated
stylesheet and module script should be inserted. Source paths must be relative,
stay inside the project, and remain outside a separate `dist` output directory.
Existing output directories without the builder's stamp are preserved by
refusing the build. A successful build replaces only its own output directory.
Failed builds leave the original project unchanged.

The app writes `gopherforge.frontend.lock.json`. It is its own offline format,
not `package-lock.json`, `bun.lock` or a claim of npm solver compatibility.
Exact versions, `*`, and simple three-component `^` / `~` ranges are accepted
against the fixed catalog. Git URLs, registry tags and missing packages fail
without attempting a download. React DOM also requires the pinned React and
scheduler packages.

## What works

- Browser JS, JSX, TS and TSX through bundled esbuild 0.28.2 WASI.
- Bundled React / React DOM 19.3.1 and scheduler 0.28.0.
- Multiple local components and modules, hooks, reducers, forms, lazy imports
  bundled into the output, CSS, JSON and inline SVG/text imports.
- Relative imports and generated browser assets; local JSON fixture requests.
- Existing Go commands for the Go part of the project, independently.

TypeScript is transpiled without a type checker. Unsupported Node built-ins
fail. Full npm/Bun, Node server code, Vite configuration/plugins, native addons,
arbitrary package scripts and automatic installation of new packages are absent.
Importing a complex React project may require adapting its dependencies and
build configuration to these limits.

## Isolation and budgets

The compiler sees a fresh WASI job tree containing project sources and selected
bundled package sources. Its virtual root is this temporary tree, never the
device root. No guest sockets, shell, child process or project plugin is exposed.
The compiler parses source; it does not run package scripts or frontend code.

Generated browser code runs in a nonpersistent WebKit store. A custom scheme
serves only this project's generated files and local JSON fixtures. No TCP
listener is opened. Content rules, CSP and navigation policy block external
HTTP(S), WebSockets, frames, workers, file URLs and popups. The app does not
forward arbitrary requests to Go handlers.

| Resource | Limit |
| --- | --- |
| Source project | 2,000 files / 32 MiB UTF-8 |
| Generated output | 100 files / 8 MiB UTF-8 |
| Compiler WASI linear memory | 384 MiB |
| Compiler WASI table | 65,536 elements |
| Captured compiler stdout / stderr | 1 MiB each |
| package.json / recipe | 256 KiB / 16 KiB |

These compiler limits do not change existing Go guest memory or module-download
budgets. Simulator results do not establish physical-device memory, thermal or
battery behavior.

## Gin boundary

The template's Go code uses the existing educational Gin-compatible subset.
`go run` checks registered routes through `httptest`; it is not a long-running
HTTP server. The React preview reads an explicit JSON fixture with the same
request/response shape. Edit and compare both sides to study a contract, without
giving the guest networking or pretending arbitrary backend routes are live.

## Verification

[Dated check record](examples/offline-frontend/check-2026-10-27.json): 36 focused
simulator checks passed, including the native UI flow and the combined React
build → Go route-check flow. The record includes source/resource hashes,
screenshots, the existing unrelated 500-line gate failure and remaining
physical-device/performance limitations. It is not a claim that the entire
repository test suite is green or that this feature has shipped to TestFlight.
