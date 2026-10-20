"use client";
import Link from "next/link";
import { useDeferredValue, useEffect, useState } from "react";
import { interviewURL } from "@/lib/interview";
import {
  readAssessments,
  readStudy,
  studyEvent,
  studyURL,
  type Assessment,
  type Bookmark,
} from "@/lib/study";
import { interviewDirections as directions } from "@/lib/interview-map";
const statuses = [
  { id: "all", label: "All guides" },
  { id: "todo", label: "To prepare" },
  { id: "revisit", label: "Revisit" },
  { id: "understood", label: "Understood" },
];
type Filters = {
  query: string;
  direction: string;
  level: string;
  status: string;
};
const defaults: Filters = {
  query: "",
  direction: "all",
  level: "",
  status: "all",
};
export function InterviewIndex({
  questions,
  topics,
  levels,
}: {
  questions: {
    id: string;
    title: string;
    prompt: string;
    topic: string;
    level: number;
  }[];
  topics: { id: string; title: string; route: string }[];
  levels: string[];
}) {
  const [filters, setFilters] = useState(defaults);
  const [marks, setMarks] = useState<Record<string, Assessment>>({});
  const [bookmark, setBookmark] = useState<Bookmark | null>(null);
  const needle = useDeferredValue(filters.query).trim().toLowerCase();
  useEffect(() => {
    const refresh = () => {
      setMarks(readAssessments());
      setBookmark(readStudy().interview);
    };
    const readFilters = () => {
      const params = new URLSearchParams(window.location.search);
      setFilters({
        query: (params.get("q") ?? "").slice(0, 256),
        direction: directions.some((d) => d.id === params.get("direction"))
          ? params.get("direction")!
          : "all",
        level: levels.some((_, i) => String(i + 1) === params.get("level"))
          ? params.get("level")!
          : "",
        status: statuses.some((s) => s.id === params.get("status"))
          ? params.get("status")!
          : "all",
      });
    };
    refresh();
    readFilters();
    window.addEventListener(studyEvent, refresh);
    window.addEventListener("storage", refresh);
    window.addEventListener("popstate", readFilters);
    return () => {
      window.removeEventListener(studyEvent, refresh);
      window.removeEventListener("storage", refresh);
      window.removeEventListener("popstate", readFilters);
    };
  }, [levels]);
  function update(patch: Partial<Filters>) {
    const next = { ...filters, ...patch };
    setFilters(next);
    const url = new URL(window.location.href);
    for (const [key, value, fallback] of [
      ["q", next.query, ""],
      ["direction", next.direction, "all"],
      ["level", next.level, ""],
      ["status", next.status, "all"],
    ]) {
      if (value === fallback) url.searchParams.delete(key);
      else url.searchParams.set(key, value);
    }
    window.history.replaceState(
      window.history.state,
      "",
      url.pathname + url.search + url.hash,
    );
  }
  const visible = questions.filter(
    (q) =>
      (filters.direction === "all" ||
        directions
          .find((d) => d.id === filters.direction)
          ?.topics.includes(q.topic)) &&
      (!filters.level || q.level === Number(filters.level)) &&
      (filters.status === "all" ||
        (filters.status === "todo"
          ? marks[q.id] !== "understood"
          : marks[q.id] === filters.status)) &&
      `${q.title} ${q.prompt} ${topics.find((t) => t.id === q.topic)?.title}`
        .toLowerCase()
        .includes(needle),
  );
  const visibleIDs = new Set(visible.map((q) => q.id));
  const resume = questions.find((q) => q.id === bookmark?.id);
  const understood = questions.filter(
    (q) => marks[q.id] === "understood",
  ).length;
  const revisit = questions.filter((q) => marks[q.id] === "revisit").length;
  const filtered = Boolean(
    needle ||
    filters.direction !== "all" ||
    filters.level ||
    filters.status !== "all",
  );
  return (
    <>
      <div className="progress-summary">
        <div>
          <strong>
            {understood} of {questions.length} understood
            {revisit ? ` · ${revisit} to revisit` : ""}
          </strong>
          <p>
            Your place and study marks stay in this browser. No account needed.
          </p>
        </div>
        {resume && bookmark ? (
          <Link
            className="button secondary"
            href={studyURL("interview", bookmark)}
          >
            Continue: {resume.title}
          </Link>
        ) : (
          <Link className="button" href={interviewURL(questions[0].id)}>
            Start preparing →
          </Link>
        )}
      </div>
      <div className="course-controls">
        <label className="course-search">
          Search interview guides
          <input
            type="search"
            maxLength={256}
            placeholder="Cancellation, MongoDB, Codex…"
            value={filters.query}
            onChange={(e) => update({ query: e.target.value })}
          />
        </label>
        <fieldset className="progress-filter">
          <legend>Show</legend>
          <div>
            {statuses.map((s) => (
              <button
                key={s.id}
                type="button"
                aria-pressed={filters.status === s.id}
                onClick={() => update({ status: s.id })}
              >
                {s.label}
              </button>
            ))}
          </div>
        </fieldset>
      </div>
      <fieldset className="progress-filter interview-levels">
        <legend>Difficulty</legend>
        <div>
          {["All levels", ...levels].map((l, i) => (
            <button
              type="button"
              key={l}
              aria-pressed={filters.level === (i ? String(i) : "")}
              onClick={() => update({ level: i ? String(i) : "" })}
            >
              {l}
            </button>
          ))}
        </div>
      </fieldset>
      <div className="course-results">
        <p role="status" className="result-count">
          {visible.length} guides in your interview map
        </p>
        {filtered && (
          <button
            className="text-button"
            type="button"
            onClick={() => update(defaults)}
          >
            Show the whole map ↗
          </button>
        )}
      </div>
      <div className="course-forest">
        <nav className="course-directions" aria-label="Interview directions">
          <p className="eyebrow">CHOOSE YOUR DIRECTION</p>
          <button
            type="button"
            aria-pressed={filters.direction === "all"}
            onClick={() => update({ direction: "all" })}
          >
            <span className="direction-number" aria-hidden="true">
              ∞
            </span>
            <span>
              Whole interview map
              <small>
                {topics.length} topics · {questions.length} guides
              </small>
            </span>
          </button>
          {directions.map((d, i) => (
            <button
              type="button"
              key={d.id}
              aria-pressed={filters.direction === d.id}
              onClick={() => update({ direction: d.id })}
            >
              <span className="direction-number" aria-hidden="true">
                {String(i + 1).padStart(2, "0")}
              </span>
              <span>
                {d.title}
                <small>
                  {d.topics.length} topics ·{" "}
                  {questions.filter((q) => d.topics.includes(q.topic)).length}{" "}
                  guides
                </small>
              </span>
            </button>
          ))}
        </nav>
        <div className="course-trees">
          {directions.map((d, i) => {
            const branches = topics.filter(
              (t) =>
                d.topics.includes(t.id) &&
                visible.some((q) => q.topic === t.id),
            );
            if (!branches.length) return null;
            return (
              <section
                className="course-tree"
                key={d.id}
                aria-labelledby={`interview-${d.id}`}
              >
                <header className="tree-root">
                  <span className="tree-root-number" aria-hidden="true">
                    {String(i + 1).padStart(2, "0")}
                  </span>
                  <div>
                    <h2 id={`interview-${d.id}`}>{d.title}</h2>
                    <p>{d.description}</p>
                  </div>
                </header>
                <div className="tree-branches">
                  {branches.map((t) => {
                    const all = questions.filter((q) => q.topic === t.id);
                    const count = all.filter(
                      (q) => marks[q.id] === "understood",
                    ).length;
                    return (
                      <details
                        className="tree-unit"
                        key={`${t.id}:${filtered}:${needle}:${filters.status}:${filters.level}`}
                        open={
                          filtered ||
                          t.id === resume?.topic ||
                          (!resume && t.id === topics[0].id)
                            ? true
                            : undefined
                        }
                      >
                        <summary>
                          <span className="unit-node" aria-hidden="true">
                            {count === all.length ? "✓" : "+"}
                          </span>
                          <span className="unit-heading">
                            <strong>{t.title}</strong>
                            <span>{t.route}</span>
                          </span>
                          <span className="unit-count">
                            {count}/{all.length}
                            <small>understood</small>
                          </span>
                          <span className="unit-chevron" aria-hidden="true">
                            ⌄
                          </span>
                        </summary>
                        <ol
                          className="unit-lessons"
                          aria-label={`${t.title} guides`}
                        >
                          {all
                            .filter((q) => visibleIDs.has(q.id))
                            .map((q) => (
                              <li
                                key={q.id}
                                className={[
                                  marks[q.id] === "understood"
                                    ? "is-completed"
                                    : "",
                                  q.id === bookmark?.id ? "is-current" : "",
                                ].join(" ")}
                              >
                                <Link
                                  className="tree-lesson"
                                  href={interviewURL(q.id)}
                                  aria-current={
                                    q.id === bookmark?.id
                                      ? "location"
                                      : undefined
                                  }
                                >
                                  <span
                                    className="lesson-node"
                                    aria-hidden="true"
                                  >
                                    {marks[q.id] === "understood"
                                      ? "✓"
                                      : marks[q.id] === "revisit"
                                        ? "↺"
                                        : String(all.indexOf(q) + 1).padStart(
                                            2,
                                            "0",
                                          )}
                                  </span>
                                  <span className="tree-lesson-text">
                                    <strong>{q.title}</strong>
                                    <span>{q.prompt}</span>
                                    <span className="tree-lesson-meta">
                                      {levels[q.level - 1]} ·{" "}
                                      {marks[q.id] === "understood"
                                        ? "Understood"
                                        : marks[q.id] === "revisit"
                                          ? "Revisit"
                                          : "Prepare & explain"}
                                      {q.id === bookmark?.id
                                        ? " · Your saved place"
                                        : ""}
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
          {!visible.length && (
            <div className="empty">
              <h2>No matching guides</h2>
              <p>Try a broader search or another difficulty.</p>
              <button
                type="button"
                className="button secondary"
                onClick={() => update(defaults)}
              >
                Clear filters
              </button>
            </div>
          )}
        </div>
      </div>
      <div className="local-note">
        <p>
          Every guide is open. Difficulty describes the reasoning expected, not
          a hiring guarantee. Study marks are separate from course completion.
        </p>
      </div>
    </>
  );
}
