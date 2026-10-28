# Execution limits and Stop

The current native engine is WasmKit 0.3.1 with token threading. Its inspected `EngineInterceptor` calls function entry/exit hooks; those hooks are not an instruction-loop cancellation API and cannot throw. Cancelling a Swift Task does not prove that a synchronous `wasi.start` has stopped.

What is enforced for an ordinary guest program:

- Linear memory: 64 MiB, subject to the resource limiter.
- Function table: 32,768 elements.
- Captured stdout and stderr: at most 1 MiB each, with further bytes drained and counted as discarded.
- Filesystem access: only the explicit preopened guest directories. This restricts access; it does **not** bound writes within an allowed directory.
- No guest native network sockets or cgo/native assembly.

What is not guaranteed:

- No enforced wall-clock/CPU deadline for ordinary native execution.
- No guaranteed Stop for a tight loop. A loop that neither grows memory nor crosses a debugger checkpoint can keep executing. Closing and reopening the app may be necessary; a background Task cancellation is not presented as proof of termination.
- No enforced aggregate guest file-write quota. Output capture limits do not protect arbitrary writes to guest-visible files.

The source debugger stops at instrumented checkpoints and is intentionally limited to supported own-source operations. That is not a universal engine interruption facility. Settings states these boundaries. Do not promote source instrumentation, async timeout races or detached Tasks as a complete runtime watchdog.

A future Stop must be tested against CPU-only loops, output loops, file-writing loops, recursive code, repeated Stop/restart and recovery of subsequent jobs. A future quota must reject writes before they exceed its storage budget and report the reason. Public browser arbitrary execution additionally requires a disposable Worker with demonstrated termination/recovery, separate from native QA. Those gates have not passed and no public browser runner is enabled by this audit checkpoint.
