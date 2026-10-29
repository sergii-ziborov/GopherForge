## Heap size is not the same question as heap depth

When someone asks how deep a Go heap can become, several different questions may be hiding inside the phrase. They might mean the depth of a linked object graph, the amount of retained memory, the depth of a recursive call stack, or the amount of pointer-bearing data the collector must inspect. Those quantities are related in an application, but they are not interchangeable runtime settings.

Consider a service that stores a hierarchy of documents. One representation is a long chain of nodes; another is a balanced tree. A separate bug keeps a tiny slice of a large input buffer in every cached result. The hierarchy may have a dramatically different logical depth in the two representations while the slice bug, which has almost no visible graph depth, dominates retained bytes. Optimizing the wrong quantity produces an elegant data structure without fixing the memory incident.

This guide investigates those distinctions with two original experiments: equal-sized node graphs and a small view retaining a large backing array. The lab ran with native Go 1.27.3 on darwin/arm64, Apple M4, GOMAXPROCS two. Each case used a fresh process. The data and complete sources are downloadable; the results are observations about those controlled programs, not a universal ranking of linked lists and trees.

## Trace ownership from a root to an object

An object remains live when the running program can still reach it through the relevant roots and references. A reference can be indirect: a global cache points to an entry, the entry points to a closure, and the closure keeps a large buffer reachable. Removing one local variable does not break that entire ownership path if another path still exists.

The official [GC guide](https://go.dev/doc/gc-guide) introduces reachability and roots. Use that model to ask a concrete question during an incident: which owner still has a reason to access this object? An object can be reachable even when the application will never use it again. The collector preserves the program's reachable state; it does not infer the business meaning of an expired cache entry.

Unreachable cycles are not automatically permanent leaks. A cycle with no remaining root path is different from a cycle held in a global registry. In the first case, circular references alone do not create an application owner. In the second, the registry does. Drawing the incoming root edge often explains the incident more clearly than drawing every link inside the cycle.

Start with the [reachability lesson](/learn/runtime.gc-reachability), then annotate a real ownership path: who adds an entry, who removes it, and what event establishes that removal is safe. Those answers connect lifetime semantics to code that a reviewer can inspect.

## Separate call-stack depth from object-graph depth

A deeply recursive function can create a deep call stack. A deeply linked heap structure can exist even when the program traverses it iteratively. The stack-depth problem belongs to the traversal algorithm and its execution; the graph-depth problem belongs to the stored relationships. A change from recursion to iteration does not automatically change which heap objects remain reachable.

Our graph validator uses an explicit work list rather than recursively visiting a hundred thousand nodes. That makes the validation independent of a recursive call chain of the same depth. The helper is deliberately limited to the acyclic chain and tree produced by the lab; it is not a general-purpose graph walker that detects arbitrary cycles.

The [stack-and-heap lesson](/learn/runtime.stack-and-heap) explains the ownership distinction. Avoid simplistic rules such as all local variables live on the stack or returning a pointer always establishes one fixed allocation cost. Compiler decisions, object size, inlining and how a value is used affect the actual program. For allocation placement, inspect the selected compiler and measure the built workload.

Most importantly, do not look for one heap-depth switch that solves all three problems: recursive stack growth, retained data and collector work. A robust investigation names the quantity it is measuring before choosing the tool or changing the representation.

## Compare equal node types before comparing shapes

The graph experiment allocates one hundred thousand objects of exactly the same Node type in each case. Every node has two pointer fields and a fixed payload. Both graphs have one root and exactly one fewer non-nil edges than nodes. The chain uses one child link per node; the balanced tree distributes those same edges across two child fields.

```go
type Node struct {
    Left, Right *Node
    Payload [48]byte
}
```

Construction temporarily uses an index slice so that the requested topology can be built easily. The lab does not return that slice. It performs a collection after construction and validation before taking the graph measurements. Otherwise the index would keep every node directly reachable and add a different ownership structure to the experiment.

This control matters more than the choice of an impressive-looking graph size. A comparison that changes the node type, object count, payload size and root count simultaneously cannot isolate the meaning of depth. Even our controlled comparison changes edge placement and locality together with logical depth, so it cannot establish that depth alone caused a timing difference.

```sh
go build -o memlab ./cmd/memlab
GOGC=100 ./memlab -mode chain
GOGC=100 ./memlab -mode tree
```

The program prints node count and logical depth alongside memory observations. That lets a reader verify what was constructed before interpreting what the runtime measured.

## What the graph experiment showed

The table reports medians from three fresh processes for each shape. Byte deltas are measured after collection relative to a pre-construction baseline. The scannable-heap value comes from the runtime metric with that definition; it is not a stopwatch measurement or an exact count of live pointer edges.

| Shape | Nodes | Logical depth | Retained heap delta | Scannable heap delta |
| --- | ---: | ---: | ---: | ---: |
| Chain | 100,000 | 100,000 | 6,409,896 bytes | 1,600,328 bytes |
| Balanced tree | 100,000 | 17 | 6,409,992 bytes | 1,600,416 bytes |

The logical depths were very different while these two memory quantities were almost identical in this experiment. That is the useful structural result. It does not prove identical collection latency. The lab also timed seven complete forced collections per process: the median of those process medians was about 1.501 milliseconds for the chain and 0.624 milliseconds for the tree in this run.

Those timings include more than pure pointer scanning. The experiment is small, sequential and not a randomized production benchmark; locality, work distribution and system activity can influence it. We preserve the raw rounds instead of promoting the ratio into a general rule that trees make Go GC a particular amount faster. Equal bytes do not imply identical runtime behavior, and different depths do not by themselves explain every observed difference.

## Bytes and pointer-bearing content describe different costs

A payload consisting of bytes does not contain the same reference structure as a collection of pointer-rich objects. Both occupy memory, but they do not present identical tracing work. Conversely, a compact object can retain a large amount of other data through its references. The size of the owner is not the size of everything it keeps alive.

The [runtime/metrics reference](https://pkg.go.dev/runtime/metrics) defines /gc/scan/heap:bytes as scannable heap space. Keep that definition separate from live heap bytes, object count and collection duration. A metric that sounds like scanning is not automatically a measurement of work performed during the request you are investigating.

For a cache design, inspect representation as well as capacity. Can an entry store a compact identifier rather than a reference to a large request object? Does a shared index keep an entire graph alive after individual entries expire? Is a byte blob large but pointer-free, or does an object contain many relationships that must remain traversable?

These questions do not imply that pointers are bad or that every structure should be flattened. Pointer-based structures can make mutation and ownership clearer. The right comparison includes access patterns, correctness, allocation behavior and measured collector effects. Our [GC tuning guide](/news/go-garbage-collector-gogc-gomemlimit-lab) explains why changing a collector percentage cannot replace those design decisions.

## A thirty-two-byte view can retain sixteen MiB

The second experiment allocates a sixteen-MiB backing array and returns only its first thirty-two bytes. One mode keeps the ordinary view. Another uses a full-slice expression to restrict capacity to thirty-two. The third copies the prefix into independent storage. All three modes return the same visible byte contents.

The [slice specification](https://go.dev/ref/spec#Slice_types) explains the relationship between a slice and its underlying array. Restricting capacity changes what later reslicing and appending can do through that slice; it does not create an independent backing allocation. The [slices.Clip contract](https://pkg.go.dev/slices#Clip) is useful when reviewing that distinction.

| Result mode | Visible length | Visible capacity | Post-GC heap delta, median |
| --- | ---: | ---: | ---: |
| View | 32 | 16,777,216 | 16,786,976 bytes |
| Capacity clipped | 32 | 32 | 16,786,960 bytes |
| Independent copy | 32 | 32 | 9,776 bytes |

These deltas include small runtime and experiment overheads; the last row does not mean a thirty-two-byte result intrinsically needs 9,776 bytes. The large difference is the retained backing array. The example gives a concrete reason to ask which storage a small result owns, rather than assuming its length describes its retained footprint.

## Copy at a lifetime boundary, not automatically everywhere

An independent result can be the correct choice when a small piece of a large input must live much longer than that input's processing window. The [bytes.Clone documentation](https://pkg.go.dev/bytes#Clone) describes a standard way to establish that independence. The lab's helper keeps the ownership decision explicit.

```go
func CopyPrefix(buf []byte, n int) []byte {
    return bytes.Clone(buf[:n])
}
```

Its caller supplies a valid length. A unit test checks both mutation directions: changing the copy must not change the source, and changing the source must not change the copy. Checking only equal contents would miss an aliasing defect. The lab's measurement then answers a different question: whether the large source allocation remains live after the helper returns.

Copying everything is not a universal optimization. If the source already has the correct lifetime, a copy can add allocation traffic and CPU with no useful reduction in retained data. If a result contains nested references, copying only an outer container may leave inner objects shared. Define the intended ownership depth instead of using the word copy as though it always meant recursively independent data.

Our earlier [slice ownership article](/news/go-slices-backing-array-append-clip-clone) covers append and cloning behavior in detail. Here the key is lifetime: a small retained view can be expensive because of the object it keeps reachable, not because the slice descriptor itself is large.

## Look for hidden owners in closures, queues and registries

A retention investigation should follow more than obvious struct fields. A closure can capture a large input. A buffered channel can retain queued messages. A blocked goroutine can keep values needed by its suspended work. A registry can preserve an object after the feature that created it has already finished.

For example, a callback that returns a small prefix may still capture the original buffer. Moving the callback into a cache extends that buffer's lifetime even if the caller drops every direct slice reference. The fix may be to capture an independent result, bound the cache or remove the callback at the correct lifecycle event. Which change is correct depends on the feature's contract.

Separate useful retained work from abandoned work. A queue containing ten deliberately admitted jobs is different from an unbounded queue accepting requests faster than workers can finish. A goroutine intentionally waiting for its owner is different from a goroutine whose owner has disappeared. Collector tuning does not provide the missing admission limit or cancellation path.

Use [goroutine ownership and leak investigation](/news/go-1-27-goroutine-leak-profiles) and [bounded work](/learn/concurrency.bounded-work) together with heap profiles. The allocation site tells you where an object came from; the application ownership path explains why it is still there. Both are needed before removing or changing the object safely.

## Pools and weak references do not remove lifetime design

A sync.Pool is a reuse mechanism with a specific contract, not a durable cache with an application-defined byte ceiling. The [sync.Pool documentation](https://pkg.go.dev/sync#Pool) allows stored items to be removed. Code must remain correct if a requested reusable item is unavailable. Conversely, retaining very large buffers for possible reuse can keep capacity associated with a workload after the useful request has ended.

Choose a reuse policy with an explicit size boundary when the workload needs one. Rejecting oversized buffers from a reuse path may be more understandable than treating every previously allocated capacity as valuable. Test correctness without relying on a particular object being returned by the pool.

Weak references can support specialized cache designs, but they change what the cache promises. The [weak package](https://pkg.go.dev/weak) is not a substitute for deterministic resource release, and a weakly held value may be unavailable when requested. The Go team's [cleanup and weak-reference article](https://go.dev/blog/cleanups-and-weak) discusses these lower-level tools and their constraints.

For files, transactions, sockets and other externally limited resources, keep explicit ownership and cleanup. A garbage collector decides memory reachability, not the business deadline for releasing a connection or closing a descriptor. Do not make an operational resource budget depend on when an unreachable object happens to be collected.

## Validate reachability experiments without measuring compiler accidents

The lab keeps the result alive through the measurement boundary with runtime.KeepAlive. This is important because a value can stop being needed by the program before the end of a source-level scope. The [runtime contract](https://pkg.go.dev/runtime#KeepAlive) explains the purpose of the call. In this experiment it helps ensure that the object whose retention we want to measure remains relevant until the observation is complete.

KeepAlive is not a mutex, a general lifetime extension for unrelated objects or a way to repair unsafe concurrent access. It simply belongs to the experiment's ownership boundary. Likewise, forcing GC establishes a controlled observation point here; it does not represent normal request-level service behavior.

Use fresh processes to reduce contamination from previous experiment modes. Validate the graph and result contents before interpreting the memory numbers. Record the runtime, architecture and environment, and preserve raw measurements rather than just a rounded chart. If a result changes after a toolchain update, begin by reproducing the same program and checking which assumption changed.

The test suite checks the graph construction and copy semantics separately from the memory observations. That separation makes a failure easier to interpret: an incorrect graph is not evidence about GC, and a noisy timing is not evidence that the graph's ownership contract is wrong.

## Turn heap evidence into an ownership change

An actionable memory investigation ends with a specific lifetime decision. Perhaps a cache stores an independent identifier instead of a complete request, a result copies a small prefix before crossing a long-lived boundary, or a queue stops admitting work beyond a documented budget. Verify that the change preserves the feature and reduces the quantity that was actually causing trouble.

[Download the memory lab, raw observations and tests](/downloads/go-memory-lab-20261029.zip). The archive includes equal-node graph construction, iterative validation, retention modes and their methodology. The published timings are local exploratory observations, not a universal collector benchmark or an in-app sandbox certification.

Continue with [heap-retention interview preparation](/interview/runtime.retention), [GC reachability](/learn/runtime.gc-reachability), and [allocation profiles and escape analysis](/news/go-allocation-profiling-pprof-escape-benchmarks). A useful answer to how deep is the heap starts by naming the graph, the roots and the measurement. From there, the practical question is not merely how many links an object has. It is which owner still needs those links and what event allows the retained state to end.
