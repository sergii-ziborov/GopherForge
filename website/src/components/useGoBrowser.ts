"use client";
import { useEffect, useRef, useState } from "react";
import type { GoMode, GoResult } from "@/lib/go-browser";
import {
  debugCommands,
  type DebugCommand,
  type DebugPause,
  type DebugPoint,
} from "@/lib/go-debug";
export function useGoBrowser() {
  const worker = useRef<Worker | null>(null),
    busy = useRef(false),
    timer = useRef<ReturnType<typeof setTimeout> | null>(null),
    control = useRef<Int32Array | null>(null),
    pending = useRef<{
      resolve: (r: GoResult) => void;
      reject: (e: Error) => void;
    } | null>(null),
    runningMs = useRef(0);
  const [running, setRunning] = useState(false),
    [debugging, setDebugging] = useState(false),
    [pause, setPause] = useState<DebugPause | null>(null),
    [points, setPoints] = useState<DebugPoint[]>([]),
    [stage, setStage] = useState("Ready · Go runs on this device"),
    [error, setError] = useState("");
  function clear() {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    busy.current = false;
    control.current = null;
    setRunning(false);
    setDebugging(false);
    setPause(null);
  }
  function stop(reason = "Stopped. Your source is kept.") {
    if (control.current) {
      Atomics.store(control.current, 0, 5);
      Atomics.notify(control.current, 0);
    }
    worker.current?.terminate();
    worker.current = null;
    pending.current?.reject(new Error(reason));
    pending.current = null;
    clear();
    setStage(reason);
  }
  function deadline(ms: number, message: string) {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => stop(message), ms);
  }
  useEffect(
    () => () => {
      worker.current?.terminate();
      if (timer.current) clearTimeout(timer.current);
      pending.current?.reject(new Error("Playground closed"));
    },
    [],
  );
  function command(kind: DebugCommand) {
    if (!control.current) return;
    setPause(null);
    setStage("Debug running locally");
    deadline(
      Math.max(1, 30000 - runningMs.current),
      "Debug reached its 30-second running-time limit",
    );
    Atomics.store(control.current, 0, debugCommands[kind]);
    Atomics.notify(control.current, 0);
  }
  function requestPause() {
    if (control.current) Atomics.store(control.current, 1, 1);
  }
  function start(
    files: Record<string, string>,
    mode: GoMode,
    stdin: string,
    breakpoints: Record<string, number[]> = {},
  ) {
    if (busy.current)
      return Promise.reject(new Error("The local compiler is busy"));
    if (
      mode === "debug" &&
      (!globalThis.crossOriginIsolated ||
        typeof SharedArrayBuffer === "undefined")
    )
      return Promise.reject(
        new Error(
          "This browser does not expose isolated shared memory for Debug. Reload the secure Playground page, or use Run.",
        ),
      );
    control.current =
      mode === "debug"
        ? new Int32Array(new SharedArrayBuffer(20010 * 4))
        : null;
    runningMs.current = 0;
    setPoints([]);
    setPause(null);
    setDebugging(mode === "debug");
    busy.current = true;
    setRunning(true);
    setError("");
    setStage(
      mode === "packages"
        ? "Preparing public packages"
        : "Preparing Go locally",
    );
    deadline(180000, "Preparation timed out. Your source is kept.");
    if (!worker.current) {
      const w = new Worker(
        new URL("../workers/go.worker.ts", import.meta.url),
        { type: "module" },
      );
      worker.current = w;
      w.onmessage = ({ data }) => {
        if (worker.current !== w) return;
        if (data.type === "stage" || data.type === "download") {
          setStage(data.label);
          if (
            data.type === "download" ||
            data.label.startsWith("Downloading") ||
            data.label.startsWith("Reading") ||
            data.label.startsWith("Authenticating")
          )
            deadline(180000, "Download timed out. Retry while connected.");
          else if (
            data.label.startsWith("Compile") ||
            data.label.startsWith("Link")
          )
            deadline(
              120000,
              "Compilation reached its two-minute limit. Your source is kept.",
            );
          else if (data.label.startsWith("Running"))
            deadline(
              30000,
              "Program stopped at the 30-second execution limit.",
            );
        } else if (data.type === "debug-plan") {
          setPoints(data.points);
        } else if (data.type === "paused") {
          setPause(data.pause);
          runningMs.current = data.pause.runningMs;
          setStage(
            `Paused at ${data.pause.point.file}:${data.pause.point.line}`,
          );
          deadline(
            30 * 60 * 1000,
            "Debug pause expired after 30 minutes. Source is kept.",
          );
        } else if (data.type === "result") {
          const p = pending.current;
          pending.current = null;
          clear();
          setStage(
            data.result.exitCode === 0
              ? "Finished locally"
              : "Finished with errors",
          );
          p?.resolve(data.result);
        } else if (data.type === "error") {
          const p = pending.current;
          pending.current = null;
          clear();
          setError(data.error);
          setStage("Could not finish");
          p?.reject(new Error(data.error));
        }
      };
      w.onerror = () => {
        setError(
          "The Go worker stopped. Retry, or export your project to continue in the app.",
        );
        stop("The Go worker stopped. Your source is kept.");
      };
    }
    return new Promise<GoResult>((resolve, reject) => {
      pending.current = { resolve, reject };
      worker.current!.postMessage({
        files,
        mode,
        stdin,
        breakpoints,
        ...(control.current ? { control: control.current.buffer } : {}),
      });
    });
  }
  return {
    start,
    stop,
    running,
    debugging,
    pause,
    points,
    command,
    requestPause,
    stage,
    error,
  };
}
