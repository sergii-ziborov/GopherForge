"use client";
import Link from "next/link";
import { useState } from "react";
import { interviewURL } from "@/lib/interview";
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
  const [topic, setTopic] = useState("");
  const [level, setLevel] = useState("");
  const [query, setQuery] = useState("");
  const filtered = questions.filter(
    (q) =>
      (!topic || q.topic === topic) &&
      (!level || q.level === Number(level)) &&
      `${q.title} ${q.prompt} ${q.topic} ${topics.find((t) => t.id === q.topic)?.title}`
        .toLowerCase()
        .includes(query.trim().toLowerCase()),
  );
  return (
    <>
      <div className="interview-tree" aria-label="Interview topic map">
        {topics.map((t, i) => (
          <button
            type="button"
            className={
              topic === t.id ? "topic-branch selected" : "topic-branch"
            }
            aria-pressed={topic === t.id}
            key={t.id}
            onClick={() => setTopic(topic === t.id ? "" : t.id)}
          >
            <span>
              {String(i + 1).padStart(2, "0")} /{" "}
              {questions.filter((q) => q.topic === t.id).length} GUIDES
            </span>
            <strong>{t.title}</strong>
            <small>{t.route}</small>
          </button>
        ))}
      </div>
      <div className="interview-filters" id="questions">
        <label>
          Search
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="e.g. cancellation, MongoDB, Codex"
          />
        </label>
        <label>
          Topic
          <select value={topic} onChange={(e) => setTopic(e.target.value)}>
            <option value="">All topics</option>
            {topics.map((t) => (
              <option key={t.id} value={t.id}>
                {t.title}
              </option>
            ))}
          </select>
        </label>
        <label>
          Difficulty
          <select value={level} onChange={(e) => setLevel(e.target.value)}>
            <option value="">All levels</option>
            {levels.map((l, i) => (
              <option value={i + 1} key={l}>
                {l}
              </option>
            ))}
          </select>
        </label>
      </div>
      <p role="status">
        {filtered.length} guides match. Difficulty describes the reasoning
        expected, not a hiring guarantee.
      </p>
      <div className="interview-grid">
        {filtered.map((q) => (
          <Link href={interviewURL(q.id)} key={q.id} className="interview-card">
            <p className="card-meta">
              {levels[q.level - 1]} ·{" "}
              {topics.find((t) => t.id === q.topic)?.title}
            </p>
            <h2>{q.title}</h2>
            <p>{q.prompt}</p>
            <strong>Prepare & explain →</strong>
          </Link>
        ))}
      </div>
      {!filtered.length && (
        <div className="empty-state">
          <h2>No matching guides</h2>
          <p>Try a shorter query or reset the topic and difficulty.</p>
          <button
            className="button secondary"
            type="button"
            onClick={() => {
              setTopic("");
              setLevel("");
              setQuery("");
            }}
          >
            Reset filters
          </button>
        </div>
      )}
    </>
  );
}
