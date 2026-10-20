"use client";
import { useState } from "react";
import type { Demonstration } from "@/lib/interview";
export function AlgorithmTrace({
  demonstration,
}: {
  demonstration: Demonstration;
}) {
  const [selected, setSelected] = useState(0);
  const [index, setIndex] = useState(0);
  const scenario = demonstration.cases[selected];
  const step = scenario.steps[index];
  return (
    <section
      className="algorithm-lab"
      aria-label="Interactive algorithm demonstration"
    >
      <p className="eyebrow">ALGORITHM LAB · STEP THROUGH THE INVARIANT</p>
      <label>
        Input scenario
        <select
          value={selected}
          onChange={(e) => {
            setSelected(Number(e.target.value));
            setIndex(0);
          }}
        >
          {demonstration.cases.map((c, i) => (
            <option value={i} key={c.name}>
              {c.name}
            </option>
          ))}
        </select>
      </label>
      <p className="trace-input">{scenario.input}</p>
      <div aria-live="polite" aria-atomic="true">
        <p className="card-meta">
          STEP {index + 1} / {scenario.steps.length}
        </p>
        <h3>{step.title}</h3>
        {step.rows.map((row, r) => (
          <div className="trace-row" key={r}>
            <strong>{row.label}</strong>
            <div
              className="trace-cells"
              tabIndex={0}
              role="group"
              aria-label={row.label}
            >
              {row.values.length ? (
                row.values.map((v, i) => (
                  <div
                    className={
                      row.active.includes(i)
                        ? "trace-cell active"
                        : "trace-cell"
                    }
                    key={i}
                  >
                    <span>{v}</span>
                    <small>
                      {i}
                      {row.active.includes(i) ? " · active" : ""}
                    </small>
                  </div>
                ))
              ) : (
                <span className="muted">∅ Empty</span>
              )}
            </div>
          </div>
        ))}
        <p>{step.note}</p>
        {index === scenario.steps.length - 1 && (
          <p className="trace-result">Result: {scenario.result}</p>
        )}
      </div>
      <div className="trace-controls">
        <button
          type="button"
          className="button secondary"
          disabled={index === 0}
          onClick={() => setIndex(0)}
        >
          Reset
        </button>
        <button
          type="button"
          className="button secondary"
          disabled={index === 0}
          onClick={() => setIndex((i) => i - 1)}
        >
          Back
        </button>
        <button
          type="button"
          className="button"
          disabled={index + 1 >= scenario.steps.length}
          onClick={() => setIndex((i) => i + 1)}
        >
          Next step →
        </button>
      </div>
      <p className="small-note">
        Computed traces for these inputs. Indexes identify cell positions;
        active cells are labeled as well as highlighted. Compare a boundary case
        using the scenario selector. No code is sent to a server.
      </p>
    </section>
  );
}
