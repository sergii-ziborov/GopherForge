"use client";
import Link from "next/link";
import { useState } from "react";
type Style = {
  id: string;
  title: string;
  objective: string;
  cost: string;
  ratings: { scenario: string; score: number }[];
};
export function ArchitectureExplorer({ styles }: { styles: Style[] }) {
  const scenarios = styles[0]?.ratings.map((r) => r.scenario) ?? [];
  const [scenario, setScenario] = useState(scenarios[0]);
  const ranked = styles
    .map((s) => ({
      ...s,
      score: s.ratings.find((r) => r.scenario === scenario)?.score ?? 1,
    }))
    .sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
  return (
    <>
      <label className="scenario-picker">
        What are you building?
        <select value={scenario} onChange={(e) => setScenario(e.target.value)}>
          {scenarios.map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
      </label>
      <p role="status" className="result-count">
        {ranked.length} approaches, sorted by suitability for{" "}
        {scenario.toLowerCase()}.
      </p>
      <div className="architecture-list">
        {ranked.map((s) => (
          <Link key={s.id} href={`/learn/${s.id}`} className="architecture-row">
            <div>
              <h2>{s.title}</h2>
              <p>{s.objective}</p>
            </div>
            <div className="architecture-score">
              <strong>
                {s.score}
                <small>/5</small>
              </strong>
              <span>Cost: {s.cost}</span>
            </div>
            <span aria-hidden="true">↗</span>
          </Link>
        ))}
      </div>
    </>
  );
}
