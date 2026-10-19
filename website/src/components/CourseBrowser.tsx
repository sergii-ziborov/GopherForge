"use client";
import Link from "next/link";
import { useEffect, useState, useDeferredValue } from "react";
import { readProgress, saveProgress } from "@/lib/progress";
type Summary = {
  id: string;
  title: string;
  objective: string;
  unitID: string;
  unitTitle: string;
  kind: string;
  minutes: number;
};
export function CourseBrowser({
  items,
  groups,
}: {
  items: Summary[];
  groups: { id: string; title: string }[];
}) {
  const [query, setQuery] = useState("");
  const deferred = useDeferredValue(query);
  const [unit, setUnit] = useState("all");
  const [status, setStatus] = useState("all");
  const [completed, setCompleted] = useState<string[]>([]);
  const [last, setLast] = useState<string | null>(null);
  useEffect(() => {
    const refresh = () => {
      const p = readProgress();
      setCompleted(p.completed);
      setLast(p.last);
    };
    refresh();
    const params = new URLSearchParams(window.location.search);
    const filter = params.get("unit");
    if (filter && groups.some((g) => g.id === filter)) setUnit(filter);
    setQuery((params.get("q") ?? "").slice(0, 256));
    const progress = params.get("status");
    if (progress === "done" || progress === "todo") setStatus(progress);
    window.addEventListener("gopherforge:progress", refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener("gopherforge:progress", refresh);
      window.removeEventListener("storage", refresh);
    };
  }, [groups]);
  function syncURL(q: string, u: string, s: string) {
    const url = new URL(window.location.href);
    if (q) url.searchParams.set("q", q);
    else url.searchParams.delete("q");
    if (u !== "all") url.searchParams.set("unit", u);
    else url.searchParams.delete("unit");
    if (s !== "all") url.searchParams.set("status", s);
    else url.searchParams.delete("status");
    window.history.replaceState(
      window.history.state,
      "",
      url.pathname + url.search + url.hash,
    );
  }
  const visible = items.filter(
    (l) =>
      (unit === "all" || l.unitID === unit) &&
      (status === "all" ||
        (status === "done"
          ? completed.includes(l.id)
          : !completed.includes(l.id))) &&
      `${l.title} ${l.objective} ${l.unitTitle}`
        .toLowerCase()
        .includes(deferred.toLowerCase()),
  );
  const resume = items.find((l) => l.id === last);
  const knownCompleted = items.filter((l) => completed.includes(l.id)).length;
  function reset() {
    if (window.confirm("Clear learning progress saved in this browser?")) {
      saveProgress({ version: 1, completed: [], last: null });
      setCompleted([]);
      setLast(null);
    }
  }
  return (
    <>
      <div className="progress-summary">
        <div>
          <strong>
            {knownCompleted} of {items.length} completed
          </strong>
          <p>
            Your progress stays on this device. Browser lessons do not unlock or
            change app progress.
          </p>
        </div>
        {resume ? (
          <Link className="button secondary" href={`/learn/${resume.id}`}>
            Continue: {resume.title}
          </Link>
        ) : (
          <Link href={`/learn/${items[0].id}`} className="button">
            Start with the basics →
          </Link>
        )}
      </div>
      <div className="course-filters">
        <label>
          Search lessons
          <input
            type="search"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              syncURL(e.target.value, unit, status);
            }}
            maxLength={256}
            placeholder="Try errors, Kubernetes, CQRS…"
          />
        </label>
        <label>
          Unit
          <select
            value={unit}
            onChange={(e) => {
              setUnit(e.target.value);
              syncURL(query, e.target.value, status);
            }}
          >
            <option value="all">All units</option>
            {groups.map((g) => (
              <option key={g.id} value={g.id}>
                {g.title}
              </option>
            ))}
          </select>
        </label>
        <label>
          Progress
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              syncURL(query, unit, e.target.value);
            }}
          >
            <option value="all">All lessons</option>
            <option value="todo">Not completed</option>
            <option value="done">Completed</option>
          </select>
        </label>
      </div>
      <p className="result-count" role="status">
        {visible.length} lessons {query ? `matching “${query}”` : "available"}
      </p>
      <div className="lesson-grid">
        {visible.map((l) => (
          <Link className="lesson-card" key={l.id} href={`/learn/${l.id}`}>
            <span className="card-meta">
              {l.unitTitle}{" "}
              <span>
                {completed.includes(l.id) ? "✓ Completed" : `${l.minutes} min`}
              </span>
            </span>
            <h2>{l.title}</h2>
            <p>{l.objective}</p>
            <span className="lesson-kind">
              {l.kind === "reading"
                ? "Read & check"
                : l.kind === "predict"
                  ? "Predict the output"
                  : "Code exercise"}{" "}
              <span aria-hidden="true">↗</span>
            </span>
          </Link>
        ))}
      </div>
      {!visible.length ? (
        <div className="empty">
          <h2>No matching lessons</h2>
          <p>Try a broader search or select another unit.</p>
          <button
            className="button secondary"
            onClick={() => {
              setQuery("");
              setUnit("all");
              setStatus("all");
              syncURL("", "all", "all");
            }}
          >
            Clear filters
          </button>
        </div>
      ) : null}
      <div className="local-note">
        <p>
          No sign-in, cookies or cloud progress storage. Clearing browser
          storage clears your progress.
        </p>
        {knownCompleted ? (
          <button type="button" className="text-button" onClick={reset}>
            Reset local progress
          </button>
        ) : null}
      </div>
    </>
  );
}
