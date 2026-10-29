"use client";
import { useEffect, useRef, useState } from "react";
type Run = {
  id: string;
  device: string;
  revision: number;
  phase: string;
  status: string;
  stdout: string;
  stderr: string;
};
type Room = {
  id: string;
  title: string;
  revision: number;
  role: string;
  expiresAt: number;
  files: Record<string, string>;
  participants: { id: string; name: string; kind: string }[];
  runs: Run[];
  participantCapability?: string;
  capabilities?: { owner: string; edit: string; view: string };
};
const initialFiles = {
  "go.mod": "module playground\n\ngo 1.27.1\n",
  "main.go":
    'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello from my device")\n}\n',
};
export function Playground() {
  const [room, setRoom] = useState<Room | null>(null),
    [files, setFiles] = useState<Record<string, string>>(initialFiles);
  const [active, setActive] = useState("main.go"),
    [link, setLink] = useState(""),
    [message, setMessage] = useState("");
  const [conflict, setConflict] = useState(false),
    [connected, setConnected] = useState(false),
    [busy, setBusy] = useState(false);
  const [links, setLinks] = useState<{
    owner?: string;
    edit?: string;
    view?: string;
  }>({});
  const seat = useRef(""),
    dirty = useRef(false),
    draft = useRef(files),
    draftRevision = useRef(0),
    current = useRef<Room | null>(null),
    publishing = useRef(false);
  const browserLink = (cap: string) =>
    `${location.origin}/playground#cap=${cap}`;
  async function api(body: Record<string, unknown>, token = seat.current) {
    const response = await fetch("/api/playground", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
      cache: "no-store",
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error ?? "Relay unavailable.");
    return result as Room;
  }
  function accept(value: Room, replace = false) {
    current.current = value;
    setRoom(value);
    setConnected(true);
    if (!dirty.current || replace) {
      draftRevision.current = value.revision;
      draft.current = value.files;
      setFiles(value.files);
      dirty.current = false;
      setConflict(false);
    }
  }
  function backup(value: Record<string, string>, roomID?: string) {
    try {
      localStorage.setItem(
        "gopherforge.playground.draft.v1",
        JSON.stringify({ files: value, roomID: roomID ?? null, revision: draftRevision.current }),
      );
    } catch {
      setMessage(
        "Browser storage is unavailable. Download a copy before leaving.",
      );
    }
  }
  async function join(raw: string, recovering = false) {
    if (!recovering && dirty.current && !window.confirm("Joining replaces the editor with this room. Download your current draft first if you need it. Join now?")) return;
    setBusy(true);
    setMessage("");
    try {
      const url = new URL(raw),
        cap = new URLSearchParams(url.hash.slice(1)).get("cap");
      if (
        !cap ||
        url.pathname !== "/playground" ||
        url.origin !== location.origin
      )
        throw new Error("Use a Playground link from this site.");
      const result = await api(
        { op: "join", name: "Browser guest", kind: "web" },
        cap,
      );
      seat.current = result.participantCapability!;
      const keepDraft = recovering && JSON.stringify(Object.entries(draft.current).sort()) !== JSON.stringify(Object.entries(result.files).sort());
      dirty.current = keepDraft;
      accept(result, !keepDraft);
      if (keepDraft) {
        setConflict(true);
        setMessage("Your saved local draft differs from the room. It was kept. Download your copy before loading the latest shared source.");
      }
      setLinks({
        edit: result.role !== "view" ? cap : undefined,
        view: result.role === "view" ? cap : undefined,
      });
      try {
        const saved = JSON.parse(sessionStorage.getItem("gopherforge.playground.owner." + result.id) ?? "null");
        if (saved?.owner) setLinks(saved);
      } catch { /* sharing still works without persistent tab credentials */ }
      history.replaceState(null, "", "/playground#cap=" + cap);
      if (!keepDraft) backup(result.files, result.id);
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not join.");
    } finally {
      setBusy(false);
    }
  }
  useEffect(() => {
    let saved: { files?: Record<string, string>; roomID?: string; revision?: number } | null = null;
    try {
      saved = JSON.parse(localStorage.getItem("gopherforge.playground.draft.v1") ?? "null");
      if (saved?.files && typeof saved.files["main.go"] === "string") {
        draft.current = saved.files; setFiles(saved.files); dirty.current = true;
        draftRevision.current = Number.isSafeInteger(saved.revision) ? saved.revision! : 0;
      }
    } catch { /* keep starter */ }
    if (location.hash) {
      setLink(location.href);
      const cap = new URLSearchParams(location.hash.slice(1)).get("cap");
      if (!saved?.files || saved.roomID === cap?.split(".")[0]) void join(location.href, true);
      else setMessage("An earlier local draft was kept. Download it before joining this different room; Join asks before replacing it.");
    }
    // Joining is an explicit link-open action, never a Run action.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => {
    if (!room?.id) return;
    let cancelled = false;
    const timer = setInterval(async () => {
      if (publishing.current) return;
      try {
        const next = await api({ op: "read" });
        if (
          cancelled ||
          current.current?.id !== next.id ||
          (current.current?.revision ?? 0) > next.revision
        )
          return;
        if (dirty.current && next.revision !== current.current?.revision)
          setConflict(true);
        accept(next);
      } catch (e) {
        if (!cancelled) {
          setConnected(false);
          setMessage(
            e instanceof Error ? e.message : "Offline. Your draft is kept.",
          );
        }
      }
    }, 2000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [room?.id]);
  useEffect(() => {
    if (!room || room.role === "view" || !dirty.current || conflict) return;
    const timer = setTimeout(() => {
      void publish();
    }, 700);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [files, conflict, room?.id]);
  async function create() {
    setBusy(true);
    try {
      const result = await api(
        {
          op: "create",
          title: "Go study room",
          files: draft.current,
          ttlSeconds: 3600,
        },
        "",
      );
      const caps = result.capabilities!;
      setLinks(caps);
      try { sessionStorage.setItem("gopherforge.playground.owner." + result.id, JSON.stringify(caps)); } catch { /* owner button remains available for this tab lifetime */ }
      const joined = await api(
        { op: "join", name: "Browser owner", kind: "web" },
        caps.owner,
      );
      seat.current = joined.participantCapability!;
      accept(joined, true);
      backup(joined.files, joined.id);
      history.replaceState(null, "", "/playground#cap=" + caps.edit);
      setMessage(
        "Room created for one hour. Share Edit/View deliberately; do not share Owner with an AI.",
      );
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not create room.");
    } finally {
      setBusy(false);
    }
  }
  async function publish() {
    if (!dirty.current || publishing.current || !current.current || conflict)
      return;
    publishing.current = true;
    const sent = draft.current;
    try {
      const next = await api({
        op: "write",
        revision: draftRevision.current,
        files: sent,
      });
      if (draft.current === sent) dirty.current = false;
      draftRevision.current = next.revision;
      accept(next);
      backup(draft.current, next.id);
      setMessage("Source shared. Nothing was executed.");
    } catch (e) {
      setConflict(true);
      setMessage(e instanceof Error ? e.message : "Your draft was kept.");
    } finally {
      publishing.current = false;
    }
  }
  function edit(text: string) {
    const next = { ...draft.current, [active]: text };
    dirty.current = true;
    draft.current = next;
    setFiles(next);
    backup(next, room?.id);
  }
  function download() {
    const blob = URL.createObjectURL(
      new Blob([JSON.stringify(draft.current, null, 2)], {
        type: "application/json",
      }),
    );
    const a = document.createElement("a");
    a.href = blob;
    a.download = "gopherforge-playground-files.json";
    a.click();
    setTimeout(() => URL.revokeObjectURL(blob), 1000);
  }
  async function close() {
    if (!links.owner) return;
    try {
      await api({ op: "close" }, links.owner);
      setRoom(null);
      current.current = null;
      setConnected(false);
      history.replaceState(null, "", "/playground");
      setMessage("Room closed. Your downloaded and local copies remain.");
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not close.");
    }
  }
  const appCap = links.edit ?? links.view;
  return (
    <div className="playground-workbench">
      <section className="playground-controls" aria-label="Room controls">
        <p>
          {room
            ? `${connected ? "Connected" : "Disconnected"} · ${room.role} · revision ${room.revision} · expires ${new Date(room.expiresAt).toLocaleString()}`
            : "Local draft · nothing uploaded until you create a room"}
        </p>
        {!room && (
          <>
            <button
              className="button"
              disabled={busy}
              onClick={() => void create()}
            >
              Create a one-hour room
            </button>
            <label>
              Join with an Edit/View link
              <input
                aria-label="Playground link"
                value={link}
                onChange={(e) => setLink(e.target.value)}
              />
            </label>
            <button
              className="button secondary"
              disabled={busy || !link}
              onClick={() => void join(link)}
            >
              Join room
            </button>
          </>
        )}
        <button className="button secondary" onClick={download}>
          Download my source copy
        </button>
        {room && room.role !== "view" && (
          <button
            className="button secondary"
            disabled={busy || conflict}
            onClick={() => void publish()}
          >
            Publish current edits
          </button>
        )}
        {appCap && (
          <a className="button" href={`gopherforge://playground#cap=${appCap}`}>
            Open in app to run on this device
          </a>
        )}
        {room && (
          <p>
            Browser editing and Output work here. Go runs only inside the native
            app after its local Run/Test button is pressed. Joining, AI edits
            and another participant’s run never execute code here.
          </p>
        )}
        {room && (
          <details>
            <summary>Share room / connect Claude or Codex</summary>
            <p>
              Use <code>https://gopherforge.app/mcp</code> as a Streamable HTTP
              MCP server. Give the AI an Edit or View link. No account is
              needed; anyone with the link has its role until expiry. The relay
              can read room source and output.
            </p>
            {(["edit", "view"] as const).map(
              (role) =>
                links[role] && (
                  <label key={role}>
                    {role} link
                    <input
                      readOnly
                      value={browserLink(links[role]!)}
                      onFocus={(e) => e.currentTarget.select()}
                    />
                  </label>
                ),
            )}
            <p>
              Native app support is in the next development build; App Store
              1.2.0 and candidate 1.3.1 (49) do not contain this Playground.
            </p>
          </details>
        )}
        {links.owner && room && (
          <button onClick={() => void close()}>Close this room</button>
        )}
        <p role="status">{message}</p>
        {conflict && (
          <aside>
            <strong>
              Your draft differs from the room. It has not been replaced.
            </strong>
            <p>
              Download your copy first. Then load the latest source and reapply
              the changes you want.
            </p>
            <button
              onClick={() => {
                if (current.current) {
                  accept(current.current, true);
                  backup(current.current.files, current.current.id);
                }
              }}
            >
              Load latest shared source
            </button>
          </aside>
        )}
      </section>
      <section className="playground-editor" aria-label="Shared source editor">
        <div className="playground-files">
          {Object.keys(files).map((path) => (
            <button
              key={path}
              aria-pressed={path === active}
              onClick={() => setActive(path)}
            >
              {path}
            </button>
          ))}
          {room?.role !== "view" && (
            <button
              onClick={() => {
                const path = prompt(
                  "Relative file name, for example mathx/math.go",
                );
                if (
                  path &&
                  /^[a-zA-Z0-9_/-]+\.go$/.test(path) &&
                  !path.includes("..") &&
                  !path.startsWith("/") &&
                  !Object.hasOwn(draft.current, path)
                ) {
                  const next = { ...draft.current, [path]: "package main\n" };
                  draft.current = next;
                  setFiles(next);
                  dirty.current = true;
                  backup(next, room?.id);
                  setActive(path);
                }
              }}
            >
              + File
            </button>
          )}
        </div>
        <label htmlFor="playground-source">
          {active} {room?.role === "view" ? "(read only)" : ""}
        </label>
        <textarea
          id="playground-source"
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          readOnly={room?.role === "view"}
          value={files[active] ?? ""}
          onChange={(e) => edit(e.target.value)}
        />
      </section>
      <section className="playground-output" aria-label="Shared device output">
        <h2>Output from connected devices</h2>
        <p>
          {room?.participants.map((p) => `${p.name} (${p.kind})`).join(" · ") ||
            "No room participants yet"}
        </p>
        {!room?.runs.length && (
          <p>No runs yet. Source editing does not execute code.</p>
        )}
        {room?.runs
          .slice()
          .reverse()
          .map((run) => (
            <article key={run.id}>
              <h3>
                {run.device} · {run.phase} · {run.status}
              </h3>
              <p>
                Source revision {run.revision}
                {run.revision !== room.revision
                  ? " · older source"
                  : " · current source"}
                . Result reported by that device.
              </p>
              <pre>
                {run.stdout ||
                  (run.status === "running"
                    ? "Building on that device…"
                    : "No stdout.")}
                {run.stderr && `\n${run.stderr}`}
              </pre>
            </article>
          ))}
      </section>
    </div>
  );
}
