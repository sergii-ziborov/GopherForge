import expansion from "@/content/interview-expansion.json";
// Dates describe content edits, not the date the page was requested.
export const curriculumUpdatedOn = "2026-10-29";
const expansionUpdatedOn = "2026-10-28";
const earlierCurriculumOn = "2026-10-27";
const auditChangedLessons = new Set([
  "architecture.bff",
  "architecture.clean-onion",
  "architecture.cqrs",
  "architecture.ddd",
  "architecture.event-driven",
  "architecture.event-sourcing",
  "architecture.layered",
  "architecture.microkernel",
  "architecture.microservices",
  "architecture.modular-monolith",
  "architecture.pipes-filters",
  "architecture.serverless",
  "architecture.simple-monolith",
  "architecture.soa",
  "architecture.vertical-slice",
  "architecture.web-queue-worker",
  "clean.configuration",
  "clean.errors",
  "clean.interfaces",
  "clean.names",
  "clean.ownership",
  "clean.refactoring",
  "clean.solid",
  "clean.table-tests",
  "patterns.abstract-factory",
  "patterns.actor-owner",
  "patterns.adapter",
  "patterns.bridge",
  "patterns.cancellation",
  "patterns.chain",
  "patterns.circuit-breaker",
  "patterns.command",
  "patterns.composite",
  "patterns.decorator",
  "patterns.facade",
  "patterns.factory-method",
  "patterns.fan-in",
  "patterns.flyweight",
  "patterns.interpreter",
  "patterns.iterator",
  "patterns.mediator",
  "patterns.memento",
  "patterns.observer",
  "patterns.proxy",
  "patterns.retry",
  "patterns.singleton",
  "patterns.state",
  "patterns.strategy",
  "patterns.template-method",
  "patterns.worker-pool",
]);
const auditChangedUnits = new Set([
  "architecture",
  "clean-code",
  "patterns-behavioral",
  "patterns-creational",
  "patterns-go",
  "patterns-structural",
]);
const changedLessons = new Set([
  "collections.make-and-new",
  "generics.constraints",
  "generics.containers",
  "collections.iterators",
  "stdlib.json-v2-contracts",
  "stdlib.json-presence",
  "stdlib.json-input-policy",
  "concurrency.waitgroup-go",
  "concurrency.synctest",
  "concurrency.errgroup",
  "sql.pool-lifetime",
  "sql.rows-and-context",
  "sql.transaction-owner",
  "sql.isolation-and-locks",
  "sql.retry-and-idempotency",
  "ai.go-workflow",
  "ai.repository-guidance",
  "ai.verify-generated-go",
  "ai.trust-boundaries",
]);
export function lessonUpdatedOn(id: string) {
  if (id.startsWith("ai.")) return "2026-10-29";
  return id === "collections.make-and-new" ||
    expansion.lessons.includes(id) ||
    auditChangedLessons.has(id)
    ? expansionUpdatedOn
    : changedLessons.has(id)
      ? earlierCurriculumOn
      : ["stdlib.borrowed-buffers", "runtime.pool-ownership"].includes(id)
        ? "2026-10-23"
        : "2026-10-20";
}
export const changedUnits = new Set([
  "generics",
  "collections",
  "stdlib",
  "concurrency",
  "sql",
  "ai",
]);
export const changedInterview = new Set([
  "algorithms.topological-sort",
  "algorithms.union-find",
  "algorithms.lru-cache",
  "algorithms.merge-intervals",
]);

export function unitUpdatedOn(id: string) {
  if (id === "ai") return "2026-10-29";
  return [
    "system-design",
    "clean-code-production",
    "gin",
    "blockchain",
    "security",
    "concurrency",
    "stdlib",
  ].includes(id) || auditChangedUnits.has(id)
    ? expansionUpdatedOn
    : changedUnits.has(id)
      ? earlierCurriculumOn
      : "2026-10-23";
}

export function interviewUpdatedOn(id: string) {
  if (["ai.workflow", "ai.security"].includes(id)) return "2026-10-29";
  return id === "language.generics" || expansion.questions.includes(id)
    ? expansion.reviewedOn
    : changedInterview.has(id)
      ? "2026-10-27"
      : "2026-10-20";
}
