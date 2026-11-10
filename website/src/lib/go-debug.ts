export type DebugPoint = {
  id: number;
  file: string;
  line: number;
  function: string;
  kind: number;
};
export type DebugFrame = {
  id: number;
  function: string;
  file: string;
  line: number;
};
export type DebugPause = {
  point: DebugPoint;
  goroutine: number;
  frames: DebugFrame[];
  locals: Record<string, string>;
  reason: "breakpoint" | "step" | "pause";
  runningMs: number;
};
export type DebugCommand = "continue" | "into" | "over" | "out";
export const debugCommands = {
  continue: 1,
  into: 2,
  over: 3,
  out: 4,
  stop: 5,
} as const;
export const debugOffset = 8;
export function bindBreakpoints(
  points: DebugPoint[],
  breakpoints: Record<string, number[]>,
  control: Int32Array,
) {
  if (points.length + debugOffset >= control.length)
    throw new Error("Too many debugger checkpoints");
  for (const [file, lines] of Object.entries(breakpoints))
    for (const line of lines) {
      const candidates = points
        .filter((p) => p.kind === 0 && p.file === file && p.line >= line)
        .sort((a, b) => a.line - b.line);
      if (!candidates.length)
        throw new Error(
          `No executable statement at ${file}:${line}. Move this breakpoint.`,
        );
      for (const point of candidates.filter(
        (p) => p.line === candidates[0].line,
      ))
        Atomics.store(control, debugOffset + point.id, 1);
    }
}
export class GoDebugSession {
  private points: Map<number, DebugPoint>;
  private stacks = new Map<number, DebugFrame[]>();
  private step: DebugCommand | undefined = "into";
  private baselineDepth = 0;
  private baselineGoroutine = 0;
  private resumed = performance.now();
  private elapsed = 0;
  private control: Int32Array;
  private paused: (snapshot: DebugPause) => void;
  constructor(
    points: DebugPoint[],
    control: Int32Array,
    paused: (snapshot: DebugPause) => void,
  ) {
    this.control = control;
    this.paused = paused;
    this.points = new Map(points.map((p) => [p.id, p]));
  }
  checkpoint(kind: number, id: number, goroutine: number, payload: Uint8Array) {
    if (Atomics.load(this.control, 0) === 5)
      throw new Error("Debugger stopped");
    const point = this.points.get(id);
    if (!point || payload.length > 65536)
      throw new Error("Invalid debugger checkpoint");
    const stack = this.stacks.get(goroutine) ?? [];
    if (kind === 1) {
      if (stack.length >= 256) throw new Error("Debugger call-stack limit");
      stack.push({
        id,
        function: point.function,
        file: point.file,
        line: point.line,
      });
    } else if (kind === 2) {
      const index = stack.findLastIndex((f) => f.id === id);
      if (index >= 0) stack.splice(index);
    } else if (stack.length)
      stack[stack.length - 1] = { ...stack.at(-1)!, line: point.line };
    if (stack.length) this.stacks.set(goroutine, stack);
    else this.stacks.delete(goroutine);
    const runningMs = this.elapsed + performance.now() - this.resumed;
    if (runningMs > 30000)
      throw new Error("Debug reached the 30-second running-time limit");
    if (kind !== 0) return;
    const breakpoint = Atomics.load(this.control, debugOffset + id) === 1,
      requested = Atomics.exchange(this.control, 1, 0) === 1;
    const step =
      this.step === "into" ||
      (this.step === "over" &&
        goroutine === this.baselineGoroutine &&
        stack.length <= this.baselineDepth) ||
      (this.step === "out" &&
        goroutine === this.baselineGoroutine &&
        stack.length < this.baselineDepth);
    if (!breakpoint && !requested && !step) return;
    const raw = JSON.parse(new TextDecoder().decode(payload));
    const locals: Record<string, string> = {};
    if (raw && typeof raw === "object" && !Array.isArray(raw))
      for (const [k, v] of Object.entries(raw).slice(0, 48))
        if (typeof v === "string") locals[k] = v.slice(0, 2048);
    this.elapsed = runningMs;
    this.baselineDepth = stack.length;
    this.baselineGoroutine = goroutine;
    this.step = undefined;
    Atomics.store(this.control, 0, 0);
    this.paused({
      point,
      goroutine,
      frames: stack.slice().reverse(),
      locals,
      reason: breakpoint ? "breakpoint" : requested ? "pause" : "step",
      runningMs,
    });
    while (Atomics.load(this.control, 0) === 0)
      Atomics.wait(this.control, 0, 0, 1000);
    const command = Atomics.exchange(this.control, 0, 0);
    if (command === 5) throw new Error("Debugger stopped");
    this.step =
      command === 2
        ? "into"
        : command === 3
          ? "over"
          : command === 4
            ? "out"
            : undefined;
    this.resumed = performance.now();
  }
}
