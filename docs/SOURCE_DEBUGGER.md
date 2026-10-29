# Source debugger (1.3.0 beta)

## Try it

1. Open Examples → Source debugger → **Source debugger walkthrough**.
2. Tap line number **12** (`result := double(start)`) to set a red breakpoint.
   The file header also offers a breakpoint menu for the caret line and Remove all.
3. Press the usual **Run** button. With no breakpoints this runs normally. With
   at least one breakpoint it automatically prepares a debug run.
4. At the pause, inspect `start = 3`, the highlighted line and the Stack menu.
5. Step Into enters `double` at line 6 with `n = 3`; Step Over reaches line 7
   with `value = 6`; Step Out returns to line 13 with `result = 6`.
6. Continue finishes and displays `6` in Output. Stop ends a paused session.

Breakpoints are stored per project on this device. Removing them restores the
ordinary execution path. A breakpoint on a blank/declaration line binds to the
next executable statement in that file. If none exists, the app asks you to
move it rather than silently ignoring it. Red markers show requested lines;
the execution highlight shows the actual bound statement.

## What is captured

The panel shows the current goroutine identifier, a call stack of instrumented
project functions and the current frame's local variables. Select a stack frame
to reveal its source location. Caller-frame locals are not captured. Step Over
and Step Out track the current goroutine and stack depth; another goroutine's
breakpoint can still stop execution. Step Into stops at the next project probe.

Values are bounded display snapshots: primitives, shortened strings, shallow
structs/pointers and container type/length/capacity summaries. Display does not
call user-defined String or MarshalJSON methods. At most 48 local names and
64 KiB of encoded values are captured at one statement. Huge/deep values are
summarized. Collection elements, watches and expression evaluation are absent.

## How it works

The original source compiles first, retaining diagnostics such as unused locals.
A trusted Go AST tool inserts checkpoints into a temporary source snapshot,
then the normal Go/WASI pipeline compiles it. A dedicated host import copies
bounded value data and pauses the compiler worker. The main UI remains free to
inspect, step and stop. The saved project and normal run cache are unchanged.
Editing source or switching projects stops the session; the editor is read-only
while a session is active. Compile, test, format and package commands retain
their existing behaviour and do not become debugger commands.

The guest retains its usual sandbox. Checkpoints grant neither networking nor
arbitrary host paths. Sources are limited to 2,000 files / 32 MiB, with at most
20,000 probes and 256 frames per goroutine. Exceeding a bound fails explicitly.

## Beta limits

This is a source-level teaching debugger, not an integration of Delve or GDB.
Only project Go source is instrumented; vendored dependencies and the standard
library are not stepped. Conditional/data breakpoints, watch expressions,
variable mutation, full goroutine inspection and live stdout streaming are not
implemented. Compiler output arrives after the run finishes. Breakpoints are
line-based and do not automatically follow later source edits.

Instrumentation adds calls, reflection and allocations and can change timing,
escape behaviour and GC. Use an ordinary run for performance or race analysis.
A pause blocks the guest interpreter; it is not an OS process or a production
server debugger. Stop takes effect at the next own-source checkpoint; an
unreturning vendor/standard-library call cannot be interrupted by a source probe.
