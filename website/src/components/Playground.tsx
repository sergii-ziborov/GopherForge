"use client";
import { useEffect, useRef, useState } from "react";
import { PlaygroundWorkbench } from "./PlaygroundWorkbench";
import { useSecureRoom } from "./useSecureRoom";
import { sourceFingerprint } from "@/lib/source-fingerprint";
import { strToU8, zipSync } from "fflate";
import type { FileAction } from "./ProjectTree";
import { useGoBrowser } from "./useGoBrowser";
import {
  examples,
  validateSource,
  renameSource,
  importSource,
  exportSource,
  safeSourcePath,
} from "@/lib/playground-files";
import type { GoMode, GoResult } from "@/lib/go-browser";
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
  participantID?: string;
  requests?: {
    id: string;
    revision: number;
    phase: "run" | "test";
    targetID?: string;
  }[];
  participants: {
    id: string;
    name: string;
    kind: string;
    cursor?: { path: string; anchor: number; head: number; revision: number };
  }[];
  changes?: { id: string; name: string; revision: number; paths: string[] }[];
  runs: Run[];
  participantCapability?: string;
  capabilities?: { owner: string; edit: string; view: string };
};
import {
  nickname,
  peerColor,
  type PeerCursor,
} from "@/lib/playground-identity";
const initialFiles = examples.hello.files;
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
  const displayName = useRef("");
  const [myName, setMyName] = useState("");
  const [identityRequest, setIdentityRequest] = useState<{
    reason: string;
    action: (name: string) => void;
  } | null>(null);
  const cursor = useRef<{ path: string; anchor: number; head: number } | null>(
    null,
  );
  function identify(reason: string, action: (name: string) => void) {
    setIdentityRequest({ reason, action });
  }
  function confirmIdentity(value: string) {
    try {
      const name = nickname(value);
      displayName.current = name;
      setMyName(name);
      try {
        localStorage.setItem("gopherforge.playground.nickname.v1", name);
      } catch {}
      const action = identityRequest?.action;
      setIdentityRequest(null);
      action?.(name);
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Choose a nickname");
    }
  }
  const compiler = useGoBrowser();
  const [stdin, setStdin] = useState(""),
    [localResult, setLocalResult] = useState<
      (GoResult & { source: string; mode: GoMode; revision?: number }) | null
    >(null);
  const [revealLine, setRevealLine] = useState(0);
  const upload = useRef<HTMLInputElement>(null);
  const execution = useRef(false);

  const [confirmation, setConfirmation] = useState<{
    message: string;
    action: () => void;
  } | null>(null);

  const seat = useRef(""),
    dirty = useRef(false),
    draft = useRef(files),
    draftRevision = useRef(0),
    current = useRef<Room | null>(null),
    publishing = useRef(false);
  const [breakpoints, setBreakpoints] = useState<Record<string, number[]>>({});
  const [prepared, setPrepared] = useState<GoResult["prepared"] | null>(null),
    [preparedMod, setPreparedMod] = useState(""),
    [sourceHash, setSourceHash] = useState("");
  const identities = useRef<Record<string, string>>({}),
    debugSource = useRef("");
  const secure = useSecureRoom({
    onFiles: (next, ids, id) => {
      const selectedID = identities.current[active];
      const selected = selectedID
        ? Object.entries(ids).find(([, value]) => value === selectedID)?.[0]
        : undefined;
      identities.current = ids;
      draft.current = next;
      setFiles(next);
      dirty.current = false;
      setActive(selected ?? (Object.hasOwn(next, active) ? active : "main.go"));
      backup(next, "secure:" + id);
    },
    onMessage: setMessage,
  });
  useEffect(() => {
    let cancelled = false;
    void sourceFingerprint(files).then((hash) => {
      if (!cancelled) setSourceHash(hash);
    });
    return () => {
      cancelled = true;
    };
  }, [files]);
  useEffect(() => {
    if (compiler.debugging && JSON.stringify(files) !== debugSource.current)
      compiler.stop("Source changed. Debug stopped; the new source is kept.");
  }, [files, compiler.debugging]);
  useEffect(() => {
    try {
      const saved = JSON.parse(
        localStorage.getItem("gopherforge.playground.breakpoints.v1") ?? "{}",
      );
      const next: Record<string, number[]> = {};
      for (const [file, lines] of Object.entries(saved))
        if (safeSourcePath(file) && Array.isArray(lines))
          next[file] = lines
            .filter((n) => Number.isSafeInteger(n) && n > 0 && n <= 20000)
            .slice(0, 128);
      setBreakpoints(next);
    } catch {}
  }, []);
  function toggleBreakpoint(file: string, line: number) {
    if (compiler.debugging) return;
    setBreakpoints((previous) => {
      const lines = previous[file] ?? [],
        next = {
          ...previous,
          [file]: lines.includes(line)
            ? lines.filter((n) => n !== line)
            : [...lines, line].sort((a, b) => a - b),
        };
      try {
        localStorage.setItem(
          "gopherforge.playground.breakpoints.v1",
          JSON.stringify(next),
        );
      } catch {}
      return next;
    });
  }
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
      signal: AbortSignal.timeout(15000),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error ?? "Relay unavailable.");
    return result as Room & { run?: Run };
  }
  function accept(value: Room, replace = false) {
    const changed =
      current.current?.id !== value.id ||
      current.current?.revision !== value.revision;
    current.current = value;
    setRoom(value);
    setConnected(true);
    if (!dirty.current || replace) {
      draftRevision.current = value.revision;
      draft.current = value.files;
      setFiles(value.files);
      setActive((previous) =>
        Object.hasOwn(value.files, previous) ? previous : "main.go",
      );
      dirty.current = false;
      setConflict(false);
      if (changed || replace) backup(value.files, value.id);
    }
  }
  function backup(value: Record<string, string>, roomID?: string) {
    try {
      localStorage.setItem(
        "gopherforge.playground.draft.v1",
        JSON.stringify({
          files: value,
          roomID: roomID ?? null,
          revision: draftRevision.current,
        }),
      );
    } catch {
      setMessage(
        "Browser storage is unavailable. Download a copy before leaving.",
      );
    }
  }
  async function join(raw: string, recovering = false) {
    if (execution.current) {
      setMessage("Stop or finish the local operation before changing rooms.");
      return;
    }
    if (
      !recovering &&
      dirty.current &&
      !window.confirm(
        "Joining replaces the editor with this room. Download your current draft first if you need it. Join now?",
      )
    )
      return;
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
        { op: "join", name: displayName.current, kind: "web" },
        cap,
      );
      seat.current = result.participantCapability!;
      const keepDraft =
        recovering &&
        JSON.stringify(Object.entries(draft.current).sort()) !==
          JSON.stringify(Object.entries(result.files).sort());
      dirty.current = keepDraft;
      accept(result, !keepDraft);
      if (keepDraft) {
        setConflict(true);
        setMessage(
          "Your saved local draft differs from the room. It was kept. Download your copy before loading the latest shared source.",
        );
      }
      setLinks({
        edit: result.role !== "view" ? cap : undefined,
        view: result.role === "view" ? cap : undefined,
      });
      try {
        const saved = JSON.parse(
          sessionStorage.getItem("gopherforge.playground.owner." + result.id) ??
            "null",
        );
        if (saved?.owner) setLinks(saved);
      } catch {
        /* sharing still works without persistent tab credentials */
      }
      history.replaceState(null, "", "/playground#cap=" + cap);
      if (!keepDraft) backup(result.files, result.id);
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not join.");
    } finally {
      setBusy(false);
    }
  }
  useEffect(() => {
    let saved: {
      files?: Record<string, string>;
      roomID?: string;
      revision?: number;
    } | null = null;
    try {
      saved = JSON.parse(
        localStorage.getItem("gopherforge.playground.draft.v1") ?? "null",
      );
      if (saved?.files && typeof saved.files["main.go"] === "string") {
        draft.current = validateSource(saved.files);
        setFiles(draft.current);
        dirty.current = true;
        draftRevision.current = Number.isSafeInteger(saved.revision)
          ? saved.revision!
          : 0;
      }
    } catch {
      /* keep starter */
    }
    try {
      const stored = localStorage.getItem("gopherforge.playground.nickname.v1");
      if (stored) {
        displayName.current = nickname(stored);
        setMyName(displayName.current);
      }
    } catch {}
    if (location.hash) {
      setLink(location.href);
      const params = new URLSearchParams(location.hash.slice(1)),
        cap = params.get("cap"),
        encryptedID = params.get("room");
      const target = encryptedID ? "secure:" + encryptedID : cap?.split(".")[0];
      if (!saved?.files || saved.roomID === target) {
        identify("Choose the name other participants will see", (name) => {
          if (encryptedID)
            void secure
              .join(location.href, true, name)
              .catch((e) => setMessage(e.message));
          else void join(location.href, true);
        });
      } else
        setMessage(
          "An earlier local draft was kept. Export it before joining this different room.",
        );
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
        const next = await api({
          op: "presence",
          name: displayName.current,
          cursor: cursor.current
            ? { ...cursor.current, revision: current.current?.revision }
            : null,
        });
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
    if (execution.current) {
      setMessage("Stop or finish the local operation before changing rooms.");
      return;
    }
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
      try {
        sessionStorage.setItem(
          "gopherforge.playground.owner." + result.id,
          JSON.stringify(caps),
        );
      } catch {
        /* owner button remains available for this tab lifetime */
      }
      const joined = await api(
        { op: "join", name: displayName.current, kind: "web" },
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
    if (secure.view) {
      secure.editFile(active, text);
      return;
    }
    const next = { ...draft.current, [active]: text };
    dirty.current = true;
    draft.current = next;
    setFiles(next);
    backup(next, room?.id);
  }
  function saveBlob(data: BlobPart, name: string, type: string) {
    const url = URL.createObjectURL(new Blob([data], { type }));
    const a = document.createElement("a");
    a.href = url;
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function download() {
    saveBlob(
      new Uint8Array(
        secure.view
          ? zipSync(
              Object.fromEntries(
                Object.entries(draft.current).map(([p, t]) => [p, strToU8(t)]),
              ),
              { level: 6 },
            )
          : exportSource(draft.current),
      ),
      "gopherforge-playground.zip",
      "application/zip",
    );
  }
  function replaceFiles(value: Record<string, string>, selected = active) {
    try {
      const next = validateSource(value);
      if (secure.view) {
        secure.replaceFiles(next);
        setActive(Object.hasOwn(next, selected) ? selected : "main.go");
        return;
      }
      draft.current = next;
      dirty.current = true;
      setFiles(next);
      setActive(Object.hasOwn(next, selected) ? selected : "main.go");
      backup(next, room?.id);
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not change files");
    }
  }
  async function run(mode: GoMode = "run") {
    if (execution.current) return;
    execution.current = true;
    let shared: { id: string; token: string; revision: number } | undefined;
    const executionToken = seat.current;
    const secureID = secure.view?.id;
    const captured = { ...draft.current },
      source = JSON.stringify(captured),
      revision = current.current?.revision;
    const clipOutput = (value: string) =>
      new TextDecoder().decode(
        new TextEncoder().encode(value).subarray(0, 60000),
      );
    try {
      validateSource(captured);
      if (room && room.role !== "view" && (mode === "run" || mode === "test")) {
        if (conflict)
          throw new Error(
            "Resolve the source conflict before sharing a run. Your draft is kept.",
          );
        if (dirty.current) {
          if (publishing.current)
            throw new Error(
              "Source is being shared. Retry Run after publication finishes.",
            );
          publishing.current = true;
          try {
            const next = await api(
              { op: "write", revision: draftRevision.current, files: captured },
              executionToken,
            );
            if (
              draft.current === captured ||
              JSON.stringify(draft.current) === source
            )
              dirty.current = false;
            draftRevision.current = next.revision;
            accept(next);
            backup(draft.current, next.id);
          } finally {
            publishing.current = false;
          }
        }
        const request = current.current?.requests?.find(
          (r) =>
            r.revision === current.current?.revision &&
            r.phase === mode &&
            (!r.targetID || r.targetID === current.current?.participantID),
        );
        const started = await api(
          {
            op: "begin_run",
            revision: draftRevision.current,
            phase: mode,
            ...(request ? { requestID: request.id } : {}),
          },
          executionToken,
        );
        shared = {
          id: started.run!.id,
          token: executionToken,
          revision: started.run!.revision,
        };
        if (JSON.stringify(started.files) !== source)
          throw new Error(
            "Shared source changed before Run. Review the current source and retry.",
          );
      }
      debugSource.current = source;
      const result = await compiler.start(captured, mode, stdin, breakpoints);
      setLocalResult({
        ...result,
        source,
        mode,
        revision: shared ? shared.revision : revision,
      });
      if (result.prepared) {
        if (
          JSON.stringify(draft.current) === source &&
          room?.role !== "view" &&
          secure.view?.role !== "view"
        ) {
          replaceFiles({ ...captured, "go.sum": result.prepared.goSum });
          setPrepared(result.prepared);
          setPreparedMod(captured["go.mod"] ?? "");
        } else
          setMessage(
            "Packages were prepared for an older manifest. Current source was kept. Prepare again.",
          );
      }
      if (
        secureID &&
        secure.view?.id === secureID &&
        secure.view.role !== "view" &&
        (mode === "run" || mode === "test" || mode === "debug")
      ) {
        secure.publishRun({
          id: crypto.randomUUID(),
          name: displayName.current || "Browser · Go",
          phase: mode,
          sourceHash: await sourceFingerprint(captured),
          stdout: clipOutput(result.stdout).slice(0, 12000),
          stderr: clipOutput(result.stderr).slice(0, 12000),
          succeeded: result.exitCode === 0,
          at: Date.now(),
        });
      }
      if (result.formatted) {
        if (JSON.stringify(draft.current) === source && room?.role !== "view")
          replaceFiles({ ...captured, ...result.formatted });
        else
          setMessage(
            "Formatting finished for an older draft. Current source was kept.",
          );
      }
      if (result.wasm)
        saveBlob(
          new Uint8Array(result.wasm),
          "gopherforge-program.wasm",
          "application/wasm",
        );
      if (shared)
        try {
          await api(
            {
              op: "finish_run",
              runID: shared.id,
              succeeded: result.exitCode === 0,
              stdout: clipOutput(result.stdout),
              stderr: clipOutput(result.stderr),
            },
            shared.token,
          );
        } catch {
          setMessage(
            "Local result was kept, but could not be shared. The room may have ended.",
          );
        }
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Could not finish locally";
      setLocalResult({
        stdout: "",
        stderr: message,
        exitCode: 1,
        durationMs: 0,
        source,
        mode,
        revision,
      });
      if (shared)
        try {
          await api(
            {
              op: "finish_run",
              runID: shared.id,
              succeeded: false,
              stdout: "",
              stderr: message.slice(0, 60000),
            },
            shared.token,
          );
        } catch {
          setMessage(
            "Local result was kept, but could not be shared. The room may have ended.",
          );
        }
    } finally {
      execution.current = false;
    }
  }
  async function close() {
    if (execution.current) {
      setMessage("Stop or finish the local operation before changing rooms.");
      return;
    }
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
  function leave() {
    if (execution.current) {
      setMessage("Stop or finish the local operation before changing rooms.");
      return;
    }
    if (publishing.current) {
      setMessage(
        "Wait for the pending publication, or download your draft while it finishes.",
      );
      return;
    }
    seat.current = "";
    current.current = null;
    draftRevision.current = 0;
    dirty.current = false;
    setRoom(null);
    setLinks({});
    setConnected(false);
    setConflict(false);
    history.replaceState(null, "", "/playground");
    backup(draft.current);
    setMessage(
      "Room left. Your local draft is kept; create another room whenever you are ready.",
    );
  }
  async function importProject(file: File) {
    try {
      if (file.size > 2 * 1024 * 1024)
        throw new Error("Choose a source archive under 2 MiB");
      const next = importSource(
        new Uint8Array(await file.arrayBuffer()),
        file.name,
      );
      setConfirmation({
        message:
          "Replace source with this import? Export a copy first if needed.",
        action: () => replaceFiles(next, "main.go"),
      });
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not import source");
    }
  }
  function fileAction(action: FileAction, path: string, value?: string) {
    try {
      if (action === "download") {
        saveBlob(
          draft.current[path],
          path.split("/").at(-1)!,
          "text/plain;charset=utf-8",
        );
        return;
      }
      if (
        compiler.debugging ||
        room?.role === "view" ||
        secure.view?.role === "view"
      )
        throw new Error("Source is read-only");
      if (action === "rename") {
        if (!value || path === "main.go")
          throw new Error("Keep main.go as the entry point");
        const affected = Object.keys(draft.current).filter(
          (p) => p === path || p.startsWith(path + "/"),
        );
        for (const old of affected) {
          const next = value + old.slice(path.length);
          if (
            !safeSourcePath(next) ||
            (Object.hasOwn(draft.current, next) && !affected.includes(next))
          )
            throw new Error(
              "Use a safe destination that does not already exist",
            );
        }
        const destinations = Object.keys(draft.current).map((file) =>
          affected.includes(file) ? value + file.slice(path.length) : file,
        );
        if (
          destinations.some((file) =>
            destinations.some(
              (other) => other !== file && other.startsWith(file + "/"),
            ),
          )
        )
          throw new Error("A destination file cannot also be a folder");
        if (secure.view) secure.rename(path, value);
        else
          replaceFiles(
            renameSource(draft.current, path, value),
            active === path || active.startsWith(path + "/")
              ? value + active.slice(path.length)
              : active,
          );
        setBreakpoints((old) =>
          Object.fromEntries(
            Object.entries(old).map(([file, lines]) => [
              file === path || file.startsWith(path + "/")
                ? value + file.slice(path.length)
                : file,
              lines,
            ]),
          ),
        );
        return;
      }
      if (action === "delete") {
        if (!path || path === "main.go")
          throw new Error("Keep main.go as the entry point");
        if (secure.view) {
          secure.deletePath(path);
          return;
        }
        const next = Object.fromEntries(
          Object.entries(draft.current).filter(
            ([p]) => p !== path && !p.startsWith(path + "/"),
          ),
        );
        replaceFiles(next, "main.go");
        return;
      }
      const target = value?.trim();
      if (
        !target ||
        !safeSourcePath(target) ||
        Object.hasOwn(draft.current, target)
      )
        throw new Error("Choose a new safe relative path");
      const folder = target.includes("/") ? target.split("/").at(-2)! : "main",
        pkg = /^[a-zA-Z_]\w*$/.test(folder)
          ? folder
          : "pkg_" + folder.replace(/[^a-zA-Z0-9_]/g, "_");
      replaceFiles(
        {
          ...draft.current,
          [target]:
            action === "duplicate"
              ? draft.current[path]
              : target.endsWith(".go")
                ? `package ${pkg}\n`
                : "",
        },
        target,
      );
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not change files");
    }
  }
  async function createRoom(encrypted: boolean, name: string) {
    if (busy || execution.current) return;
    if (room || secure.view) {
      setMessage("Leave the current room before creating another.");
      return;
    }
    setBusy(true);
    try {
      if (encrypted) await secure.create(draft.current, 3600, name);
      else await create();
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not create room");
    } finally {
      setBusy(false);
    }
  }
  function joinRoom(link: string) {
    const action = () =>
      identify("Choose your nickname before joining", (name) => {
        void (async () => {
          if (busy || execution.current) return;
          setBusy(true);
          try {
            const encrypted = new URLSearchParams(
              new URL(link).hash.slice(1),
            ).has("room");
            if (encrypted) await secure.join(link, true, name);
            else await join(link, true);
          } catch (e) {
            setMessage(
              e instanceof Error
                ? e.message
                : "Use a Playground room link from this site.",
            );
          } finally {
            setBusy(false);
          }
        })();
      });
    if (room || secure.view) {
      setMessage("Leave the current room before joining another.");
      return;
    }
    setConfirmation({
      message:
        "Joining loads the shared project. Export your current draft first if needed.",
      action,
    });
  }
  function leaveRoom() {
    if (execution.current) {
      setMessage("Stop or finish the local operation before changing rooms.");
      return;
    }
    if (secure.view) void secure.leave();
    else leave();
  }
  return (
    <PlaygroundWorkbench
      files={files}
      active={active}
      onOpen={(path, line) => {
        setActive(path);
        setRevealLine(line ?? 0);
      }}
      readOnly={room?.role === "view" || secure.view?.role === "view"}
      documentKey={secure.view?.id ?? room?.id ?? "local"}
      revealLine={revealLine}
      compiler={compiler}
      breakpoints={breakpoints}
      onBreakpoint={toggleBreakpoint}
      onClearBreakpoints={() => {
        setBreakpoints({});
        try {
          localStorage.removeItem("gopherforge.playground.breakpoints.v1");
        } catch {}
      }}
      onRun={(mode) => void run(mode)}
      result={localResult}
      sourceHash={sourceHash}
      stdin={stdin}
      onStdin={setStdin}
      onEdit={edit}
      onMessage={setMessage}
      onExport={download}
      onImport={(file) => void importProject(file)}
      onExample={(key) => {
        const example = examples[key];
        if (example)
          setConfirmation({
            message:
              "Replace the current source with this example? Export a copy first if needed.",
            action: () => {
              replaceFiles(example.files, "main.go");
              setStdin(example.stdin ?? "");
            },
          });
      }}
      onFileAction={fileAction}
      onMove={(from, folder) =>
        fileAction(
          "rename",
          from,
          (folder ? folder + "/" : "") + from.split("/").at(-1),
        )
      }
      message={message}
      room={room}
      secure={secure.view}
      awareness={secure.awareness}
      links={links}
      connected={connected}
      conflict={conflict}
      onLoadLatest={() => {
        if (current.current) {
          accept(current.current, true);
          backup(current.current.files, current.current.id);
        }
      }}
      onPublish={() => void publish()}
      connecting={busy}
      onCreate={(encrypted) =>
        identify(
          "Choose your nickname before sharing",
          (name) => void createRoom(encrypted, name),
        )
      }
      onJoin={joinRoom}
      onLeave={leaveRoom}
      onClose={() => {
        if (secure.view)
          void secure.close().catch((e) => setMessage(e.message));
        else void close();
      }}
      onRestore={secure.restore}
      confirmation={confirmation}
      onDismissConfirmation={() => setConfirmation(null)}
      nickname={myName}
      identityRequest={
        identityRequest ? { reason: identityRequest.reason } : null
      }
      onIdentity={confirmIdentity}
      onCancelIdentity={() => setIdentityRequest(null)}
      onRenameSelf={() =>
        identify("Change your participant nickname", (name) => {
          secure.setName(name);
          if (current.current)
            void api({ op: "presence", name })
              .then((next) => accept(next))
              .catch((e) => setMessage(e.message));
        })
      }
      onSelection={(anchor, head) => {
        cursor.current = { path: active, anchor, head };
      }}
      peerCursors={(room?.participants ?? []).flatMap((peer) =>
        peer.id !== room?.participantID &&
        peer.cursor &&
        peer.cursor.revision === room?.revision
          ? [
              {
                ...peer.cursor,
                id: peer.id,
                name: peer.name,
                color: peerColor(peer.id),
              },
            ]
          : [],
      )}
      prepared={prepared}
      preparedStale={
        !!prepared &&
        (preparedMod !== (files["go.mod"] ?? "") ||
          prepared.goSum !== (files["go.sum"] ?? ""))
      }
    />
  );
}
