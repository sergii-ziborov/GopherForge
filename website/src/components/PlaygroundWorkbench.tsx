"use client";
import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import { ProjectTree, type FileAction } from "./ProjectTree";
import { examples } from "@/lib/playground-files";
import type { GoMode, GoResult } from "@/lib/go-browser";
import type { useGoBrowser } from "./useGoBrowser";
import type { SecureView } from "./useSecureRoom";
import type { Awareness } from "y-protocols/awareness";
import type * as Y from "yjs";
import { nickname, type PeerCursor } from "@/lib/playground-identity";
import companion from "@/content/mcp-package.json";
const mcpSetup = `npm install --global https://gopherforge.app${companion.archive}\ngopherforge-mcp setup`;
const Editor = dynamic(() => import("./GoEditor").then((m) => m.GoEditor), {
  ssr: false,
  loading: () => <p className="gf-muted">Loading editor…</p>,
});
type Room = {
  id: string;
  role: string;
  revision: number;
  expiresAt: number;
  participants: { name: string; kind: string }[];
  runs: {
    id: string;
    device: string;
    phase: string;
    status: string;
    revision: number;
    stdout: string;
    stderr: string;
  }[];
  requests?: { revision: number }[];
  changes?: {
    id: string;
    name: string;
    revision: number;
    paths: string[];
    kind?: string;
  }[];
};
type Props = {
  nickname: string;
  identityRequest: { reason: string } | null;
  onIdentity: (name: string) => void;
  onCancelIdentity: () => void;
  onRenameSelf: () => void;
  onSelection: (anchor: number, head: number) => void;
  peerCursors: PeerCursor[];
  connecting: boolean;
  files: Record<string, string>;
  active: string;
  onOpen: (path: string, line?: number) => void;
  readOnly: boolean;
  documentKey: string;
  revealLine: number;
  compiler: ReturnType<typeof useGoBrowser>;
  breakpoints: Record<string, number[]>;
  onBreakpoint: (file: string, line: number) => void;
  onClearBreakpoints: () => void;
  onRun: (mode: GoMode) => void;
  result: (GoResult & { source: string; mode: GoMode }) | null;
  sourceHash: string;
  stdin: string;
  onStdin: (v: string) => void;
  onEdit: (v: string) => void;
  onMessage: (v: string) => void;
  onExport: () => void;
  onImport: (file: File) => void;
  onExample: (key: string) => void;
  onFileAction: (action: FileAction, path: string, value?: string) => void;
  onMove: (from: string, folder: string) => void;
  message: string;
  room: Room | null;
  secure: SecureView | null;
  awareness?: Awareness;
  links: Partial<Record<"owner" | "edit" | "view", string>>;
  connected: boolean;
  conflict: boolean;
  onLoadLatest: () => void;
  onPublish: () => void;
  onCreate: (encrypted: boolean) => void;
  onJoin: (link: string) => void;
  onLeave: () => void;
  onClose: () => void;
  onRestore: (id: string) => void;
  confirmation: { message: string; action: () => void } | null;
  onDismissConfirmation: () => void;
  prepared: GoResult["prepared"] | null;
  preparedStale: boolean;
};
const empty: number[] = [];
export function PlaygroundWorkbench(p: Props) {
  const [tab, setTab] = useState<
      "output" | "input" | "problems" | "debug" | "packages" | "room"
    >("output"),
    [filesVisible, setFilesVisible] = useState(true),
    [fontSize, setFontSize] = useState(14),
    [wrap, setWrap] = useState(false),
    [search, setSearch] = useState(0),
    [encrypted, setEncrypted] = useState(true),
    [joinLink, setJoinLink] = useState(""),
    [outputHeight, setOutputHeight] = useState(230),
    [frame, setFrame] = useState(0),
    [fileDialog, setFileDialog] = useState<{
      action: FileAction;
      path: string;
      value: string;
    } | null>(null),
    [copied, setCopied] = useState("");
  const identityModal = useRef<HTMLDialogElement>(null);
  const [identityName, setIdentityName] = useState("");
  const [identityError, setIdentityError] = useState("");
  useEffect(() => {
    if (p.identityRequest) {
      setIdentityName(p.nickname);
      setIdentityError("");
      identityModal.current?.showModal();
    }
  }, [p.identityRequest]);
  const modal = useRef<HTMLDialogElement>(null),
    fileModal = useRef<HTMLDialogElement>(null),
    upload = useRef<HTMLInputElement>(null),
    drag = useRef<number | null>(null),
    [header, setHeader] = useState(92);
  useEffect(() => {
    if (window.matchMedia("(max-width:720px)").matches) setFilesVisible(false);
  }, []);
  useEffect(() => {
    const el = document.querySelector(".site-header");
    if (!el) return;
    const observer = new ResizeObserver(() =>
      setHeader(el.getBoundingClientRect().height),
    );
    observer.observe(el);
    setHeader(el.getBoundingClientRect().height);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    try {
      const v = JSON.parse(
        localStorage.getItem("gopherforge.editor.preferences.v1") ?? "null",
      );
      if (v) {
        setFontSize(Math.min(22, Math.max(11, Number(v.fontSize) || 14)));
        setWrap(v.wrap === true);
      }
    } catch {}
  }, []);
  function preference(size: number, wrapping: boolean) {
    setFontSize(size);
    setWrap(wrapping);
    try {
      localStorage.setItem(
        "gopherforge.editor.preferences.v1",
        JSON.stringify({ fontSize: size, wrap: wrapping }),
      );
    } catch {}
  }
  useEffect(() => {
    if (p.confirmation) modal.current?.showModal();
  }, [p.confirmation]);
  useEffect(() => {
    if (fileDialog) fileModal.current?.showModal();
  }, [fileDialog]);
  useEffect(() => {
    if (p.compiler.pause) {
      setTab("debug");
      setFrame(0);
      p.onOpen(p.compiler.pause.point.file, p.compiler.pause.point.line);
    }
  }, [p.compiler.pause]);
  useEffect(() => {
    if (p.compiler.running && !p.compiler.debugging)
      setTab(
        p.compiler.stage.startsWith("Preparing public") ||
          p.compiler.stage.startsWith("Authenticating")
          ? "packages"
          : "output",
      );
  }, [p.compiler.running]);
  const resultText = (p.result?.stdout ?? "") + "\n" + (p.result?.stderr ?? ""),
    diagnostics = [
      ...resultText.matchAll(
        /(?:\/work\/)?([a-zA-Z0-9_./-]+\.go):(\d+)(?::\d+)?:? ([^\n]+)/g,
      ),
    ].filter((m) => Object.hasOwn(p.files, m[1]));
  const shared = p.secure ?? p.room,
    role = shared?.role ?? "local",
    locked = p.readOnly || p.compiler.debugging,
    totalLines = (p.files[p.active] ?? "").split("\n").length,
    bpCount = Object.values(p.breakpoints).reduce((n, v) => n + v.length, 0);
  const currentFrame = p.compiler.pause?.frames[frame];
  async function copy(value: string, label: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(label);
      setTimeout(() => setCopied(""), 2000);
    } catch {
      p.onMessage(
        "Copy is unavailable. Select the link text and copy it manually.",
      );
    }
  }
  function action(a: FileAction, path: string) {
    if (a === "download") {
      p.onFileAction(a, path);
      return;
    }
    setFileDialog({
      action: a,
      path,
      value:
        a === "rename"
          ? path
          : a === "duplicate"
            ? path.replace(/(\.[^./]+)?$/, "-copy$1")
            : a === "new-folder"
              ? (path ? path + "/" : "") + "new-package/main.go"
              : a === "new-file"
                ? (path ? path + "/" : "") + "new.go"
                : "",
    });
  }
  const secureLinks = p.secure?.links ?? p.links;
  return (
    <div
      className="gf-workspace"
      style={
        {
          "--gf-header": header + "px",
          "--gf-output": outputHeight + "px",
        } as React.CSSProperties
      }
    >
      <header className="gf-toolbar">
        <div className="gf-workspace-title">
          <span className="gf-project-logo" aria-hidden="true">
            G
          </span>
          <div>
            <h1>Go Playground</h1>
            <p>Go 1.27.1 · on your device</p>
          </div>
        </div>
        <div className="gf-toolbar-actions">
          <button
            className="gf-button gf-primary"
            disabled={p.compiler.running}
            onClick={() => p.onRun("run")}
          >
            ▶ Run
          </button>
          <button
            className="gf-button"
            disabled={p.compiler.running}
            onClick={() => p.onRun("test")}
          >
            Test
          </button>
          <button
            className="gf-button gf-debug-button"
            disabled={p.compiler.running}
            onClick={() => {
              setTab("debug");
              p.onRun("debug");
            }}
          >
            ◉ Debug
          </button>
          <button
            className="gf-button"
            disabled={!p.compiler.running}
            onClick={() => p.compiler.stop()}
          >
            ■ Stop
          </button>
          <span className="gf-toolbar-divider" />
          <button
            className="gf-button"
            disabled={p.compiler.running}
            onClick={() => p.onRun("check")}
          >
            Check
          </button>
          <button
            className="gf-button"
            disabled={p.compiler.running || locked}
            onClick={() => p.onRun("format")}
          >
            Format
          </button>
          <button
            className="gf-button"
            disabled={p.compiler.running}
            onClick={() => p.onRun("build")}
          >
            Build ↓
          </button>
          <button className="gf-button" onClick={p.onExport}>
            Export ZIP
          </button>
          <button className="gf-button gf-share" onClick={() => setTab("room")}>
            ↗ Share
          </button>
        </div>
      </header>
      <div className="gf-session-bar">
        <span className={p.compiler.running ? "gf-activity" : ""}>
          {p.compiler.pause
            ? "● Paused"
            : p.compiler.running
              ? "● " + p.compiler.stage
              : shared
                ? p.secure
                  ? "● Encrypted room"
                  : "● App / MCP room"
                : "● Local draft"}
        </span>
        <span>
          {shared
            ? `${role} · expires ${new Date(shared.expiresAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
            : "Nothing uploaded until you share"}
        </span>
        {p.secure?.peers.map((peer, i) => (
          <span className="gf-peer" key={peer.name + i}>
            <i style={{ background: peer.color }} />
            {peer.name}
          </span>
        ))}
        <a href="/guide#browser-playground">Guide ↗</a>
      </div>
      {p.message && (
        <div className="gf-notice" role="status">
          <span>{p.message}</span>
          <button aria-label="Dismiss notice" onClick={() => p.onMessage("")}>
            ×
          </button>
        </div>
      )}
      <div className={`gf-main ${filesVisible ? "" : "gf-files-hidden"}`}>
        {filesVisible && (
          <aside className="gf-sidebar">
            <div className="gf-project-heading">
              <span>▣ playground</span>
              <button
                aria-label="Hide file explorer"
                onClick={() => setFilesVisible(false)}
              >
                ‹
              </button>
            </div>
            <ProjectTree
              paths={Object.keys(p.files)}
              active={p.active}
              readOnly={locked}
              onOpen={(path) => p.onOpen(path)}
              onAction={action}
              onMove={p.onMove}
            />
            <div className="gf-sidebar-bottom">
              <label>
                <span>EXAMPLES</span>
                <select
                  aria-label="Example project"
                  value=""
                  disabled={locked || p.compiler.running}
                  onChange={(e) => p.onExample(e.target.value)}
                >
                  <option value="" disabled>
                    Open an example…
                  </option>
                  {Object.entries(examples).map(([key, e]) => (
                    <option key={key} value={key}>
                      {e.label}
                    </option>
                  ))}
                </select>
              </label>
              <button
                className="gf-button"
                disabled={locked || p.compiler.running}
                onClick={() => upload.current?.click()}
              >
                ↑ Import ZIP / JSON
              </button>
              <input
                ref={upload}
                type="file"
                accept=".zip,.json"
                style={{ display: "none" }}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  e.target.value = "";
                  if (file) p.onImport(file);
                }}
              />
              <p>
                Your draft is saved in this browser.
                <br />
                Export a copy before clearing site data.
              </p>
            </div>
          </aside>
        )}
        <section className="gf-editor-stack" aria-label="Go workspace">
          <div className="gf-file-bar">
            {!filesVisible && (
              <button
                aria-label="Show file explorer"
                onClick={() => setFilesVisible(true)}
              >
                ☷
              </button>
            )}
            <span className="gf-file-tab">
              ‹› <strong>{p.active}</strong>
              {locked && <small>read only</small>}
            </span>
            <div className="gf-editor-tools">
              <button
                aria-label="Find in file"
                onClick={() => setSearch((v) => v + 1)}
              >
                ⌕
              </button>
              <button
                aria-label="Decrease editor font"
                disabled={fontSize <= 11}
                onClick={() => preference(fontSize - 1, wrap)}
              >
                A−
              </button>
              <button
                aria-label="Increase editor font"
                disabled={fontSize >= 22}
                onClick={() => preference(fontSize + 1, wrap)}
              >
                A+
              </button>
              <button
                aria-pressed={wrap}
                aria-label="Wrap lines"
                onClick={() => preference(fontSize, !wrap)}
              >
                ↩
              </button>
            </div>
          </div>
          <div className="gf-editor-area">
            <Editor
              path={p.active}
              value={p.files[p.active] ?? ""}
              readOnly={locked}
              onChange={p.onEdit}
              onRun={() => p.onRun("run")}
              revealLine={p.revealLine}
              breakpoints={p.breakpoints[p.active] ?? empty}
              onBreakpoint={(line) => p.onBreakpoint(p.active, line)}
              debugLine={
                p.compiler.pause?.point.file === p.active
                  ? p.compiler.pause.point.line
                  : undefined
              }
              documentKey={p.documentKey}
              text={p.secure?.texts.get(p.active)}
              awareness={p.awareness}
              onLimit={() =>
                p.onMessage(
                  "This edit exceeds the 128 KiB recovery limit. Split the file or import a smaller example.",
                )
              }
              fontSize={fontSize}
              wrap={wrap}
              searchRequest={search}
              onSelection={p.onSelection}
              peerCursors={p.peerCursors}
            />
          </div>
          <div className="gf-editor-status">
            <span>
              {totalLines} lines · UTF-8 ·{" "}
              {p.active.endsWith(".go") ? "Go" : "Text"}
            </span>
            <span>Tab: 4 · Ctrl/⌘ + Enter to run</span>
          </div>
          <div
            className="gf-dock-resize"
            role="separator"
            aria-label="Resize output panel"
            aria-orientation="horizontal"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === "ArrowUp" || e.key === "ArrowDown") {
                e.preventDefault();
                setOutputHeight((v) =>
                  Math.max(
                    130,
                    Math.min(
                      window.innerHeight * 0.65,
                      v + (e.key === "ArrowUp" ? 35 : -35),
                    ),
                  ),
                );
              }
            }}
            onPointerDown={(e) => {
              drag.current = e.clientY;
              e.currentTarget.setPointerCapture(e.pointerId);
            }}
            onPointerMove={(e) => {
              if (drag.current !== null) {
                const delta = drag.current - e.clientY;
                drag.current = e.clientY;
                setOutputHeight((v) =>
                  Math.max(130, Math.min(window.innerHeight * 0.65, v + delta)),
                );
              }
            }}
            onPointerUp={() => {
              drag.current = null;
            }}
          />
          <div className="gf-dock">
            <div
              className="gf-dock-tabs"
              role="tablist"
              aria-label="Workspace panels"
            >
              {(
                [
                  ["output", "Output"],
                  ["input", "Input"],
                  [
                    "problems",
                    `Problems${diagnostics.length ? " · " + diagnostics.length : ""}`,
                  ],
                  ["debug", `Debug${bpCount ? " · " + bpCount : ""}`],
                  [
                    "packages",
                    `Packages${p.prepared ? " · " + p.prepared.modules.length : ""}`,
                  ],
                  ["room", shared ? "Room" : "Share"],
                ] as const
              ).map(([id, label]) => (
                <button
                  key={id}
                  id={"gf-tab-" + id}
                  role="tab"
                  aria-selected={tab === id}
                  aria-controls={"gf-panel-" + id}
                  onClick={() => setTab(id)}
                >
                  {label}
                </button>
              ))}
              <span className="gf-dock-state" aria-live="polite">
                {p.compiler.stage}
              </span>
            </div>
            <div
              className="gf-dock-content"
              role="tabpanel"
              id={"gf-panel-" + tab}
              aria-labelledby={"gf-tab-" + tab}
            >
              {tab === "output" && (
                <>
                  <div className="gf-output-heading">
                    <strong>This browser</strong>
                    {p.result && (
                      <span
                        className={
                          p.result.exitCode === 0 ? "gf-success" : "gf-failure"
                        }
                      >
                        {p.result.exitCode === 0
                          ? "✓ Succeeded"
                          : "Failed / stopped"}{" "}
                        · {(p.result.durationMs / 1000).toFixed(2)} s ·{" "}
                        {p.result.source === JSON.stringify(p.files)
                          ? "current source"
                          : "older source"}
                      </span>
                    )}
                  </div>
                  <pre aria-label="Local output">
                    {p.result
                      ? resultText.trim()
                      : "Choose Run or Test to try your code. Nothing runs automatically."}
                  </pre>
                  {p.secure?.runs
                    .slice()
                    .reverse()
                    .map((run) => (
                      <details key={run.id} className="gf-shared-result">
                        <summary>
                          {run.name} · {run.phase} ·{" "}
                          {run.succeeded ? "passed" : "failed"} ·{" "}
                          {run.sourceHash === p.sourceHash
                            ? "current source"
                            : "older source"}
                        </summary>
                        <pre>
                          {run.stdout}
                          {run.stderr && "\n" + run.stderr}
                        </pre>
                      </details>
                    ))}
                  {p.room?.runs
                    .slice()
                    .reverse()
                    .map((run) => (
                      <details key={run.id} className="gf-shared-result">
                        <summary>
                          {run.device} · {run.phase} · {run.status} · revision{" "}
                          {run.revision}
                          {run.revision !== p.room!.revision
                            ? " (older source)"
                            : ""}
                        </summary>
                        <pre>
                          {run.stdout}
                          {run.stderr && "\n" + run.stderr}
                        </pre>
                      </details>
                    ))}
                  {p.room?.requests?.some(
                    (r) => r.revision === p.room!.revision,
                  ) && (
                    <p className="gf-inline-note">
                      A collaborator requested a run. Review the source, then
                      choose Run or Test.
                    </p>
                  )}
                </>
              )}
              {tab === "input" && (
                <label className="gf-input-label">
                  Standard input
                  <textarea
                    aria-label="Standard input"
                    value={p.stdin}
                    onChange={(e) => p.onStdin(e.target.value)}
                    maxLength={65536}
                    placeholder="Input for fmt.Scan or bufio.Scanner…"
                  />
                  <small>
                    Provided when Run starts, followed by EOF. Not uploaded to a
                    room.
                  </small>
                </label>
              )}
              {tab === "problems" && (
                <>
                  <h2>Go diagnostics</h2>
                  {diagnostics.length ? (
                    diagnostics.map((m, i) => (
                      <button
                        className="gf-diagnostic"
                        key={i}
                        onClick={() => p.onOpen(m[1], Number(m[2]))}
                      >
                        <span>
                          {m[1]}:{m[2]}
                        </span>
                        {m[3]}
                      </button>
                    ))
                  ) : (
                    <p className="gf-muted">
                      No source diagnostics in the last result. Use Check to
                      compile without running.
                    </p>
                  )}
                </>
              )}
              {tab === "debug" && (
                <>
                  <div className="gf-debug-controls">
                    {p.compiler.pause ? (
                      <>
                        <button
                          className="gf-button gf-primary"
                          onClick={() => p.compiler.command("continue")}
                        >
                          ▶ Continue
                        </button>
                        <button
                          className="gf-button"
                          onClick={() => p.compiler.command("into")}
                        >
                          Step into
                        </button>
                        <button
                          className="gf-button"
                          onClick={() => p.compiler.command("over")}
                        >
                          Step over
                        </button>
                        <button
                          className="gf-button"
                          onClick={() => p.compiler.command("out")}
                        >
                          Step out
                        </button>
                      </>
                    ) : p.compiler.debugging ? (
                      <button
                        className="gf-button"
                        onClick={p.compiler.requestPause}
                      >
                        Ⅱ Pause
                      </button>
                    ) : (
                      <button
                        className="gf-button gf-debug-button"
                        disabled={p.compiler.running}
                        onClick={() => p.onRun("debug")}
                      >
                        ◉ Start Debug
                      </button>
                    )}
                    {p.compiler.debugging && (
                      <button
                        className="gf-button"
                        onClick={() => p.compiler.stop()}
                      >
                        ■ Stop
                      </button>
                    )}
                  </div>
                  <p className="gf-debug-location">
                    {p.compiler.pause
                      ? `${p.compiler.pause.reason} · ${p.compiler.pause.point.file}:${p.compiler.pause.point.line} · goroutine ${p.compiler.pause.goroutine}`
                      : p.compiler.debugging
                        ? "Running the immutable debug snapshot."
                        : "Click beside a line number to set a breakpoint. Debug pauses at the first statement."}
                  </p>
                  <div className="gf-debug-columns">
                    <section>
                      <h3>CALL STACK</h3>
                      {p.compiler.pause?.frames.map((f, i) => (
                        <button
                          className={`gf-stack-frame ${frame === i ? "gf-frame-selected" : ""}`}
                          key={f.id + ":" + i}
                          onClick={() => {
                            setFrame(i);
                            p.onOpen(f.file, f.line);
                          }}
                        >
                          {f.function}
                          <small>
                            {f.file}:{f.line}
                          </small>
                        </button>
                      ))}
                      {!p.compiler.pause && (
                        <p className="gf-muted">No paused frames</p>
                      )}
                    </section>
                    <section>
                      <h3>
                        LOCALS
                        {currentFrame ? " · " + currentFrame.function : ""}
                      </h3>
                      {p.compiler.pause && frame === 0 ? (
                        <table className="gf-locals">
                          <thead>
                            <tr>
                              <th>Name</th>
                              <th>Value</th>
                            </tr>
                          </thead>
                          <tbody>
                            {Object.entries(p.compiler.pause.locals).map(
                              ([key, value]) => (
                                <tr key={key}>
                                  <td>{key}</td>
                                  <td>{value}</td>
                                </tr>
                              ),
                            )}
                          </tbody>
                        </table>
                      ) : (
                        <p className="gf-muted">
                          {frame > 0
                            ? "Caller-frame locals are not captured. Select the current frame."
                            : "Pause to inspect current-frame values."}
                        </p>
                      )}
                    </section>
                  </div>
                  <details className="gf-breakpoints">
                    <summary>Breakpoints ({bpCount})</summary>
                    {Object.entries(p.breakpoints).flatMap(([file, lines]) =>
                      lines.map((line) => (
                        <button
                          key={file + line}
                          disabled={p.compiler.debugging}
                          onClick={() => p.onBreakpoint(file, line)}
                        >
                          ● {file}:{line} ×
                        </button>
                      )),
                    )}
                    {!!bpCount && (
                      <button
                        disabled={p.compiler.debugging}
                        onClick={p.onClearBreakpoints}
                      >
                        Clear all
                      </button>
                    )}
                  </details>
                  <p className="gf-muted">
                    Project source only. Bounded values; no watches or variable
                    mutation. Paused time is excluded from the 30-second run
                    budget.
                  </p>
                </>
              )}
              {tab === "packages" && (
                <>
                  <div className="gf-panel-heading">
                    <h2>Go packages</h2>
                    <button
                      className="gf-button gf-primary"
                      disabled={p.compiler.running || locked}
                      onClick={() => p.onRun("packages")}
                    >
                      ↓ Prepare packages
                    </button>
                  </div>
                  <p>
                    Reads exact public requirements from{" "}
                    <button
                      className="gf-inline-button"
                      onClick={() => p.onOpen("go.mod")}
                    >
                      go.mod
                    </button>
                    . Downloads from proxy.golang.org, verifies go.sum and the
                    signed Go checksum log, then caches compatible source on
                    this device. Your program source is not sent.
                  </p>
                  {p.preparedStale && (
                    <p className="gf-inline-note">
                      The manifest changed. Prepare again before using this
                      dependency set.
                    </p>
                  )}
                  {p.prepared?.modules.map((m) => (
                    <div className="gf-package" key={m.path}>
                      <strong>{m.path}</strong>
                      <span>{m.version}</span>
                      <small>✓ {m.checksum}</small>
                    </div>
                  ))}
                  {!p.prepared && (
                    <p className="gf-muted">
                      No prepared dependency set in this session. Verified
                      cached packages are also restored when Run starts.
                    </p>
                  )}
                  <p className="gf-muted">
                    24 modules · 512 retained files · 8 MiB source. Pure Go /
                    WASI only; no cgo, native assembly, registry scripts or
                    guest networking. Run never installs packages.
                  </p>
                </>
              )}
              {tab === "room" && (
                <>
                  <div className="gf-panel-heading">
                    <h2>
                      {p.secure
                        ? "Encrypted live room"
                        : p.room
                          ? "App / MCP room"
                          : "Code together"}
                    </h2>
                    {shared && (
                      <span className="gf-success">
                        {p.secure?.connected || p.connected
                          ? "Connected"
                          : "Offline · draft kept"}{" "}
                        · {role}
                      </span>
                    )}
                  </div>
                  {!shared ? (
                    <>
                      <div className="gf-room-create">
                        <label>
                          Room type
                          <select
                            aria-label="Room type"
                            value={encrypted ? "encrypted" : "compatible"}
                            onChange={(e) =>
                              setEncrypted(e.target.value === "encrypted")
                            }
                          >
                            <option value="encrypted">
                              Encrypted · live rooms and JavaScript MCP
                            </option>
                            <option value="compatible">
                              Compatible · iPhone/iPad and remote MCP
                            </option>
                          </select>
                        </label>
                        <button
                          className="gf-button gf-share"
                          disabled={p.compiler.running || p.connecting}
                          onClick={() => p.onCreate(encrypted)}
                        >
                          Create one-hour room
                        </button>
                      </div>
                      <p>
                        {encrypted
                          ? "End-to-end encryption and simultaneous text merging, with named cursors and change history. Native support is in the upcoming 1.3.3 build; released 1.3.2 uses Compatible rooms."
                          : "Supports the released iPhone/iPad app and remote Claude/Codex MCP. The relay can read source and Output; source conflicts preserve your local copy."}
                      </p>
                      <form
                        className="gf-room-join"
                        onSubmit={(e) => {
                          e.preventDefault();
                          p.onJoin(joinLink);
                        }}
                      >
                        <label>
                          Join with a room link
                          <input
                            aria-label="Playground link"
                            value={joinLink}
                            onChange={(e) => setJoinLink(e.target.value)}
                            placeholder="https://gopherforge.app/playground#…"
                          />
                        </label>
                        <button
                          className="gf-button"
                          disabled={
                            !joinLink || p.compiler.running || p.connecting
                          }
                        >
                          Join room
                        </button>
                      </form>
                    </>
                  ) : (
                    <>
                      <p>
                        You are <strong>{p.nickname}</strong> ·{" "}
                        <button
                          className="gf-inline-button"
                          onClick={p.onRenameSelf}
                        >
                          Change nickname
                        </button>
                      </p>
                      <p>
                        {p.secure
                          ? "Anyone with an Edit/View link and its encryption key has that role until expiry. The encryption key stays in the link fragment and is not sent to the relay."
                          : "Share Edit or View deliberately. This compatible room is readable by the relay and uses revision checks."}
                      </p>
                      {p.secure && (
                        <details>
                          <summary>Connect an agent with encrypted MCP</summary>
                          <p className="gf-muted">
                            Install GopherForge&apos;s own JavaScript companion
                            on the agent&apos;s computer with Node.js 22+. Setup
                            asks for its nickname and this room&apos;s complete
                            Edit/View link, and keeps the key client-side.
                          </p>
                          <pre>{mcpSetup}</pre>
                          <button
                            className="gf-inline-button"
                            onClick={() => void copy(mcpSetup, "mcp-setup")}
                          >
                            {copied === "mcp-setup"
                              ? "Copied"
                              : "Copy MCP setup commands"}
                          </button>
                          <p className="gf-muted">
                            The agent can read/edit and show its named cursor.
                            Run/Test requests appear in Recent changes; you
                            review and press the local button.
                          </p>
                          <a href="/guide/mcp#encrypted-setup">
                            Encrypted MCP, npm and client configuration →
                          </a>
                        </details>
                      )}
                      {p.room && (
                        <details>
                          <summary>
                            Connect an AI with compatible remote MCP
                          </summary>
                          <p className="gf-muted">
                            Use a compatible MCP client. Share Edit for changes
                            or View for reading; keep Owner private.
                          </p>
                          <p>
                            <code>https://gopherforge.app/mcp</code>{" "}
                            <button
                              className="gf-inline-button"
                              onClick={() =>
                                void copy(
                                  "https://gopherforge.app/mcp",
                                  "mcp-endpoint",
                                )
                              }
                            >
                              {copied === "mcp-endpoint"
                                ? "Copied"
                                : "Copy endpoint"}
                            </button>
                          </p>
                          <p className="gf-muted">
                            Ask the assistant to call playground_join with a
                            nickname, read the current revision, make a small
                            patch and request Test. You review the change and
                            press Test locally.
                          </p>
                          <a href="/guide/mcp">
                            Complete connection and sharing guide →
                          </a>
                        </details>
                      )}
                      {!!(
                        p.secure?.changes.length || p.room?.changes?.length
                      ) && (
                        <details>
                          <summary>Recent changes</summary>
                          {(p.secure?.changes ?? p.room?.changes ?? [])
                            .slice(-8)
                            .reverse()
                            .map((change) => (
                              <p className="gf-muted" key={change.id}>
                                <strong>{change.name}</strong>{" "}
                                {change.kind === "request run"
                                  ? "requested Run for"
                                  : change.kind === "request test"
                                    ? "requested Test for"
                                    : "changed"}{" "}
                                {change.paths.join(", ")}
                              </p>
                            ))}
                        </details>
                      )}
                      {(["edit", "view"] as const).map(
                        (role) =>
                          secureLinks[role] && (
                            <label className="gf-share-link" key={role}>
                              {role === "edit" ? "Edit link" : "View link"}
                              <div>
                                <input
                                  aria-label={role + " link"}
                                  readOnly
                                  value={
                                    p.secure
                                      ? secureLinks[role]
                                      : location.origin +
                                        "/playground#cap=" +
                                        secureLinks[role]
                                  }
                                  onFocus={(e) => e.currentTarget.select()}
                                />
                                <button
                                  className="gf-button"
                                  onClick={() =>
                                    copy(
                                      p.secure
                                        ? secureLinks[role]!
                                        : location.origin +
                                            "/playground#cap=" +
                                            secureLinks[role],
                                      role,
                                    )
                                  }
                                >
                                  {copied === role ? "Copied" : "Copy"}
                                </button>
                              </div>
                            </label>
                          ),
                      )}
                      {p.room && (
                        <>
                          <button
                            className="gf-button"
                            disabled={locked || p.conflict}
                            onClick={p.onPublish}
                          >
                            Publish current edits
                          </button>
                          {(p.links.edit ?? p.links.view) && (
                            <a
                              className="gf-button"
                              href={
                                "gopherforge://playground#cap=" +
                                (p.links.edit ?? p.links.view)
                              }
                            >
                              Open in app ↗
                            </a>
                          )}
                        </>
                      )}
                      <div className="gf-room-actions">
                        <button
                          className="gf-button"
                          disabled={p.compiler.running}
                          onClick={p.onLeave}
                        >
                          Leave · keep source
                        </button>
                        {secureLinks.owner && (
                          <button
                            className="gf-button"
                            disabled={p.compiler.running}
                            onClick={p.onClose}
                          >
                            Close room
                          </button>
                        )}
                      </div>
                    </>
                  )}
                  {p.conflict && (
                    <div className="gf-inline-note">
                      <strong>
                        Your local draft differs from shared source.
                      </strong>
                      <p>
                        Export your copy, then load the latest version and
                        reapply your changes.
                      </p>
                      <button className="gf-button" onClick={p.onLoadLatest}>
                        Load latest shared source
                      </button>
                    </div>
                  )}
                  {!!p.secure?.conflicts && (
                    <p className="gf-inline-note">
                      Concurrent file names collided. Both copies were kept
                      under conflict names; rename or remove the extra copy.
                    </p>
                  )}
                  {!!p.secure?.deleted.length && (
                    <details>
                      <summary>
                        Recover deleted files ({p.secure.deleted.length})
                      </summary>
                      {p.secure.deleted.map((f) => (
                        <button
                          className="gf-button"
                          key={f.id}
                          onClick={() => p.onRestore(f.id)}
                        >
                          Restore {f.path}
                        </button>
                      ))}
                    </details>
                  )}
                  <p className="gf-muted">
                    A temporary room is not a backup. Export your source before
                    expiry. <a href="/guide/mcp">MCP and native setup ↗</a>
                  </p>
                </>
              )}
            </div>
          </div>
        </section>
      </div>
      {p.identityRequest && (
        <dialog
          ref={identityModal}
          className="gf-modal"
          onCancel={p.onCancelIdentity}
        >
          <form
            onSubmit={(e) => {
              e.preventDefault();
              try {
                p.onIdentity(nickname(identityName));
              } catch (error) {
                setIdentityError(
                  error instanceof Error ? error.message : "Choose a nickname",
                );
              }
            }}
          >
            <h2>How should we call you?</h2>
            <p>
              {p.identityRequest.reason}. Your nickname appears beside your
              cursor and changes. It is a display label, not a verified
              identity.
            </p>
            <label>
              Nickname
              <input
                autoFocus
                aria-label="Nickname"
                maxLength={32}
                value={identityName}
                onChange={(e) => setIdentityName(e.target.value)}
                autoComplete="nickname"
                placeholder="For example, Alex"
              />
            </label>
            {identityError && <p role="alert">{identityError}</p>}
            <div className="gf-modal-actions">
              <button
                className="gf-button"
                type="button"
                onClick={p.onCancelIdentity}
              >
                Cancel
              </button>
              <button className="gf-button gf-primary" type="submit">
                Continue
              </button>
            </div>
          </form>
        </dialog>
      )}
      {p.confirmation && (
        <dialog
          ref={modal}
          className="gf-modal"
          onCancel={p.onDismissConfirmation}
        >
          <h2>Replace source?</h2>
          <p>{p.confirmation.message}</p>
          <div className="gf-modal-actions">
            <button className="gf-button" onClick={p.onDismissConfirmation}>
              Keep current source
            </button>
            <button
              className="gf-button gf-primary"
              onClick={() => {
                p.confirmation!.action();
                p.onDismissConfirmation();
              }}
            >
              Replace source
            </button>
          </div>
        </dialog>
      )}
      {fileDialog && (
        <dialog
          ref={fileModal}
          className="gf-modal"
          onCancel={() => setFileDialog(null)}
        >
          <form
            onSubmit={(e) => {
              e.preventDefault();
              p.onFileAction(
                fileDialog.action,
                fileDialog.path,
                fileDialog.value,
              );
              setFileDialog(null);
            }}
          >
            <h2>
              {fileDialog.action === "delete"
                ? "Delete source?"
                : fileDialog.action === "rename"
                  ? "Rename / move"
                  : fileDialog.action === "duplicate"
                    ? "Duplicate file"
                    : "Create source"}
            </h2>
            {fileDialog.action === "delete" ? (
              <p>
                Delete {fileDialog.path} and its contents? Export a copy if you
                need it. Encrypted rooms also keep deleted files in recovery.
              </p>
            ) : (
              <label>
                Relative path
                <input
                  autoFocus
                  value={fileDialog.value}
                  onChange={(e) =>
                    setFileDialog({ ...fileDialog, value: e.target.value })
                  }
                  placeholder="mathx/math.go"
                />
              </label>
            )}
            <div className="gf-modal-actions">
              <button
                className="gf-button"
                type="button"
                onClick={() => setFileDialog(null)}
              >
                Cancel
              </button>
              <button className="gf-button gf-primary" type="submit">
                {fileDialog.action === "delete" ? "Delete" : "Save"}
              </button>
            </div>
          </form>
        </dialog>
      )}
    </div>
  );
}
