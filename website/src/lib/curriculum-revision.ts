// Dates describe content edits, not the date the page was requested.
export const curriculumUpdatedOn = "2026-10-27";
const changedLessons = new Set([
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
  return changedLessons.has(id)
    ? curriculumUpdatedOn
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
