import data from "@/content/news.json";
import images from "@/content/news-images.json";
export type News = (typeof data)[number];
export const news = [...data].sort(
  (a, b) => Date.parse(b.editionDate) - Date.parse(a.editionDate),
);
export const newsURL = (slug: string) => `/news/${slug}`;
export const newsForLesson = (id: string) =>
  news
    .filter((n) => n.sections.some((s) => s.body.includes(`](/learn/${id})`)))
    .slice(0, 3);
export const newsImage = (id: string) => images[id as keyof typeof images];
export const dateLabel = (date: string) =>
  new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(date));
export const imageCaption: Record<string, string> = {
  gohiring:
    "Define → Compare → Build → Review. Identify the cohort, keep incompatible measurements separate, build inspectable evidence and review the result. Conceptual preparation workflow, not measured hiring odds or an offer guarantee.",
  ctxbudget:
    "Locate → Budget → Cancel → Verify. Find the waiting stage, preserve the parent budget, signal cancellation and observe completion. Conceptual diagram; cancellation does not by itself prove remote rollback or worker completion.",
  godirections:
    "Search, usage and engineering fit answer different questions. Compare the measurement methods before choosing a direction. Conceptual illustration; the saved Google Trends observations are reported in the text, not drawn by ImageGen.",
  slogfield:
    "Select → Structure → Redact → Test. Choose approved fields, preserve their schema, exclude secrets and check failure behavior. Conceptual workflow, not a claim of lossless delivery or universal redaction.",
  invariants:
    "Define → Protect → Publish → Test. Name the invariant, protect its complete transition, preserve ownership during publication and test a controlled competing operation. Conceptual diagram, not a synchronization benchmark.",
  retrykey:
    "Identify → Commit → Replay → Reconcile. Preserve logical operation identity, record its local effect and receipt together, replay matching results and investigate uncertain outcomes. A local boundary does not cover independent external effects.",
  streamio:
    "Read → Bound → Parse → Check. Preserve final bytes, enforce a finite envelope, validate document framing and report the actual outcome. Conceptual workflow, not a throughput benchmark.",
  gotime:
    "Define → Locate → Calculate → Test. Name the time contract, select location rules, distinguish elapsed and calendar arithmetic, and test fixed transition cases. Conceptual illustration, not a timezone map.",
  gcpacer:
    "Measure → Bound → Adjust → Verify. Establish live data and allocation demand, bound admitted work, change one runtime setting and verify useful completions. Conceptual illustration, not measured telemetry.",
  heapgraph:
    "Roots → References → Live data → Release. An object remains reachable while any root path survives. Removing one reference is insufficient when another owner still retains it. Conceptual ownership diagram.",
  alloclab:
    "Reproduce → Profile → Change → Recheck. Separate allocation traffic, retained data and execution time; preserve equivalent output before comparing resources. Conceptual workflow, not benchmark results.",
  sqlpool:
    "Budget → Bound → Release → Measure. Allocate database capacity across replicas, limit waiting, return owned connections and distinguish pool wait from query time.",
  shutdown:
    "Stop routing → Drain → Join → Close. Coordinate admission, accepted requests, worker completion and resource cleanup inside one finite grace period.",
  synctest:
    "Signal → Advance → Settle → Assert. Establish explicit events, move virtual time, observe settled workers and check one precise contract.",
  emudhra:
    "Inventory → Rebuild → Verify → Rollout. Find the actual executable, pin the fixed toolchain, inspect build evidence and check every replica. A toolchain update is not a deployment.",
  jsonv2:
    "Inventory → Compare → Stage → Verify. Record the wire contract, test behavioral differences, roll out deliberately, and verify consumer compatibility.",
  backpressure:
    "Admit → Bound → Cancel → Measure. Make capacity explicit, keep waiting finite, propagate cancellation, and measure useful completions alongside rejections.",
  survey:
    "Observe → Reproduce → Explain → Share. Collect concrete experience; no 2026 survey results have been published in this report.",
  slices:
    "View and Clip share existing elements. Clip limits capacity; Clone copies the outer elements into separate storage. Nested references can remain shared.",
  buffers:
    "Borrow → Copy → Release → Reuse. Make a result independent before its temporary owner becomes reusable.",
  errors:
    "Return → Wrap → Match → Test. Return nil for success, preserve intended classification, and test pointer/value error forms.",
  gopls24:
    "Pin → Inspect → Test → Measure. Verify the selected server, review semantics and measure a representative workspace.",
  launch:
    "Learn → Try → Check → Continue. Browser and app save progress separately.",
  vscode:
    "Edit → Inspect → Test → Review. Editor assistance still needs engineering judgment.",
  security:
    "Inventory → Rebuild → Test → Rollout. Updating a toolchain does not redeploy binaries.",
  dapr: "Go app → Sidecar → Service. Share one deadline budget, bound retries, use idempotency and measure failures.",
  gopls:
    "Select → Answer → Review → Apply → Test. A recommended workflow, not a universal editor feature.",
  rebuild:
    "Pin inputs → Build twice → Compare → Record. Matching artifacts are evidence, not a complete security audit.",
  http: "Share client → Set deadline → Close body → Trace reuse. HTTP/1 cleanup is bounded; measure the real workload.",
  simd: "Profile → Compare results → Benchmark → Keep fallback. CPU features and workload shape decide the result.",
  alloc:
    "Pin workload → Count allocations → Profile memory → Check latency. Faster allocation does not fix retained objects.",
  leaks:
    "Capture → Find owner → Fix exit → Test shutdown. An empty leak profile is not proof of no leaks.",
};
