"use client";
import Link from "next/link";
import { useEffect, useState, useDeferredValue } from "react";
import { readProgress, saveProgress } from "@/lib/progress";
import { directions } from "@/lib/course-map";
type Summary = {
  id: string;
  title: string;
  objective: string;
  unitID: string;
  unitTitle: string;
  kind: string;
  minutes: number;
};
const progressFilters = [
  { id: "all", label: "All lessons" },
  { id: "todo", label: "To learn" },
  { id: "done", label: "Completed" },
];
export function CourseBrowser({
  items,
  groups,
}: {
  items: Summary[];
  groups: { id: string; title: string; summary: string }[];
}) {
  const [query, setQuery] = useState("");
  const deferred = useDeferredValue(query);
  const [unit, setUnit] = useState("all");
  const [direction, setDirection] = useState("all");
  const [status, setStatus] = useState("all");
  const [completed, setCompleted] = useState<string[]>([]);
  const [last, setLast] = useState<string | null>(null);
  useEffect(() => {
    const refresh = () => {
      const p = readProgress();
      setCompleted(p.completed);
      setLast(p.last);
    };
    const readFilters = () => {
      const params = new URLSearchParams(window.location.search);
      const filter = params.get("unit");
      const validUnit = groups.some((g) => g.id === filter) ? filter! : "all";
      setUnit(validUnit);
      const track = params.get("direction");
      setDirection(
        directions.find((d) => d.units.some((id) => id === validUnit))?.id ??
          (directions.some((d) => d.id === track) ? track! : "all"),
      );
      setQuery((params.get("q") ?? "").slice(0, 256));
      const progress = params.get("status");
      setStatus(progress === "done" || progress === "todo" ? progress : "all");
    };
    refresh();
    readFilters();
    window.addEventListener("gopherforge:progress", refresh);
    window.addEventListener("storage", refresh);
    window.addEventListener("popstate", readFilters);
    return () => {
      window.removeEventListener("gopherforge:progress", refresh);
      window.removeEventListener("storage", refresh);
      window.removeEventListener("popstate", readFilters);
    };
  }, [groups]);
  function syncURL(q: string, u: string, s: string, d: string) {
    const url = new URL(window.location.href);
    for (const [key, value, fallback] of [
      ["q", q, ""],
      ["unit", u, "all"],
      ["status", s, "all"],
      ["direction", d, "all"],
    ]) {
      if (value !== fallback) url.searchParams.set(key, value);
      else url.searchParams.delete(key);
    }
    window.history.replaceState(
      window.history.state,
      "",
      url.pathname + url.search + url.hash,
    );
  }
  const done = new Set(completed);
  const needle = deferred.trim().toLowerCase();
  const visible = items.filter(
    (l) =>
      (unit === "all" || l.unitID === unit) &&
      (direction === "all" ||
        directions
          .find((d) => d.id === direction)
          ?.units.some((id) => id === l.unitID)) &&
      (status === "all" ||
        (status === "done" ? done.has(l.id) : !done.has(l.id))) &&
      `${l.title} ${l.objective} ${l.unitTitle}`.toLowerCase().includes(needle),
  );
  const visibleIDs = new Set(visible.map((l) => l.id));
  const resume = items.find((l) => l.id === last);
  const knownCompleted = items.filter((l) => done.has(l.id)).length;
  const filtered = Boolean(
    needle || unit !== "all" || status !== "all" || direction !== "all",
  );
  function clearFilters() {
    setQuery("");
    setUnit("all");
    setStatus("all");
    setDirection("all");
    syncURL("", "all", "all", "all");
  }
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
            Saved in this browser. Web progress is independent of app progress.
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
      <div className="course-controls">
        <label className="course-search">
          Search the course
          <input
            type="search"
            value={query}
            maxLength={256}
            placeholder="Errors, Kubernetes, CQRS…"
            onChange={(e) => {
              setQuery(e.target.value);
              syncURL(e.target.value, unit, status, direction);
            }}
          />
        </label>
        <fieldset className="progress-filter">
          <legend>Show</legend>
          <div>
            {progressFilters.map((filter) => (
              <button
                type="button"
                key={filter.id}
                aria-pressed={status === filter.id}
                onClick={() => {
                  setStatus(filter.id);
                  syncURL(query, unit, filter.id, direction);
                }}
              >
                {filter.label}
              </button>
            ))}
          </div>
        </fieldset>
      </div>
      <div className="course-results">
        <p className="result-count" role="status">
          {visible.length} {visible.length === 1 ? "lesson" : "lessons"}
          {needle ? ` matching “${query}”` : " in your learning map"}
        </p>
        {filtered ? (
          <button className="text-button" type="button" onClick={clearFilters}>
            Show the whole map ↗
          </button>
        ) : null}
      </div>
      <div className="course-forest">
        <nav className="course-directions" aria-label="Learning directions">
          <p className="eyebrow">CHOOSE YOUR DIRECTION</p>
          <button
            type="button"
            aria-pressed={direction === "all"}
            onClick={() => {
              setDirection("all");
              setUnit("all");
              syncURL(query, "all", status, "all");
            }}
          >
            <span className="direction-number" aria-hidden="true">
              ∞
            </span>
            <span>
              Whole learning map
              <small>
                {groups.length} units · {items.length} lessons
              </small>
            </span>
          </button>
          {directions.map((d, index) => (
            <button
              type="button"
              key={d.id}
              aria-pressed={direction === d.id}
              onClick={() => {
                setDirection(d.id);
                setUnit("all");
                syncURL(query, "all", status, d.id);
              }}
            >
              <span className="direction-number" aria-hidden="true">
                {String(index + 1).padStart(2, "0")}
              </span>
              <span>
                {d.title}
                <small>
                  {d.units.length} units ·{" "}
                  {
                    items.filter((l) => d.units.some((id) => id === l.unitID))
                      .length
                  }{" "}
                  lessons
                </small>
              </span>
            </button>
          ))}
        </nav>
        <div className="course-trees">
          {directions.map((d, index) => {
            const branches = groups.filter(
              (g) =>
                d.units.some((id) => id === g.id) &&
                visible.some((l) => l.unitID === g.id),
            );
            if (!branches.length) return null;
            return (
              <section
                className="course-tree"
                key={d.id}
                aria-labelledby={`direction-${d.id}`}
              >
                <header className="tree-root">
                  <span className="tree-root-number" aria-hidden="true">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  <div>
                    <h2 id={`direction-${d.id}`}>{d.title}</h2>
                    <p>{d.description}</p>
                  </div>
                </header>
                <div className="tree-branches">
                  {branches.map((g) => {
                    const allLessons = items.filter((l) => l.unitID === g.id);
                    const shownLessons = allLessons.filter((l) =>
                      visibleIDs.has(l.id),
                    );
                    const unitDone = allLessons.filter((l) =>
                      done.has(l.id),
                    ).length;
                    return (
                      <details
                        className="tree-unit"
                        key={`${g.id}:${filtered}:${needle}:${status}`}
                        open={
                          filtered || g.id === groups[0].id ? true : undefined
                        }
                      >
                        <summary>
                          <span className="unit-node" aria-hidden="true">
                            {unitDone === allLessons.length ? "✓" : "+"}
                          </span>
                          <span className="unit-heading">
                            <strong>{g.title}</strong>
                            <span>{g.summary}</span>
                          </span>
                          <span className="unit-count">
                            {unitDone}/{allLessons.length}
                            <small>completed</small>
                          </span>
                          <span className="unit-chevron" aria-hidden="true">
                            ⌄
                          </span>
                        </summary>
                        <ol
                          className="unit-lessons"
                          aria-label={`${g.title} lessons`}
                        >
                          {shownLessons.map((l) => (
                            <li
                              key={l.id}
                              className={
                                done.has(l.id) ? "is-completed" : undefined
                              }
                            >
                              <Link
                                href={`/learn/${l.id}`}
                                className="tree-lesson"
                              >
                                <span
                                  className="lesson-node"
                                  aria-hidden="true"
                                >
                                  {done.has(l.id)
                                    ? "✓"
                                    : String(
                                        allLessons.indexOf(l) + 1,
                                      ).padStart(2, "0")}
                                </span>
                                <span className="tree-lesson-text">
                                  <strong>{l.title}</strong>
                                  <span>{l.objective}</span>
                                  <span className="tree-lesson-meta">
                                    {l.kind === "reading"
                                      ? "Read & check"
                                      : l.kind === "predict"
                                        ? "Predict the output"
                                        : "Code exercise"}{" "}
                                    · {l.minutes} min
                                    {done.has(l.id) ? " · Completed" : ""}
                                  </span>
                                </span>
                                <span
                                  className="lesson-arrow"
                                  aria-hidden="true"
                                >
                                  ↗
                                </span>
                              </Link>
                            </li>
                          ))}
                        </ol>
                      </details>
                    );
                  })}
                </div>
              </section>
            );
          })}
          {!visible.length ? (
            <div className="empty">
              <h2>No matching lessons</h2>
              <p>Try a broader search or another direction.</p>
              <button
                className="button secondary"
                type="button"
                onClick={clearFilters}
              >
                Clear filters
              </button>
            </div>
          ) : null}
        </div>
      </div>
      <div className="local-note">
        <p>
          Open any branch and choose a lesson. The map suggests an order; every
          lesson is freely accessible.
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
