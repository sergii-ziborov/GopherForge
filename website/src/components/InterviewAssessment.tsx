"use client";
import { useEffect, useState } from "react";
const key = "gopherforge.interview.self-assessment.v1";
function read(): Record<string, string> {
  try {
    const value = JSON.parse(localStorage.getItem(key) ?? "{}");
    return value && typeof value === "object" && !Array.isArray(value)
      ? value
      : {};
  } catch {
    return {};
  }
}
export function InterviewAssessment({ id }: { id: string }) {
  const [mark, setMark] = useState("");
  const [message, setMessage] = useState("");
  useEffect(() => {
    const m = read()[id];
    setMark(m === "revisit" || m === "understood" ? m : "");
  }, [id]);
  function save(next: string) {
    const marks = read();
    if (next) marks[id] = next;
    else delete marks[id];
    setMark(next);
    try {
      localStorage.setItem(key, JSON.stringify(marks));
      setMessage("Saved in this browser.");
    } catch {
      setMessage("Browser storage unavailable; kept for this page only.");
    }
  }
  return (
    <section className="completion">
      <h2>How did you do?</h2>
      <p>
        Self-assessment, not a compiler pass or interview score. Explain the
        reasoning unaided before marking understood.
      </p>
      <div className="trace-controls">
        <button
          type="button"
          className="button secondary"
          aria-pressed={mark === "revisit"}
          onClick={() => save("revisit")}
        >
          Revisit
        </button>
        <button
          type="button"
          className="button"
          aria-pressed={mark === "understood"}
          onClick={() => save("understood")}
        >
          Understood
        </button>
        <button
          type="button"
          className="button secondary"
          onClick={() => save("")}
        >
          Clear mark
        </button>
      </div>
      <p role="status">
        {mark ? `Marked ${mark}. ` : "Not marked. "}
        {message ||
          "Progress stays on this browser, separate from course completion."}
      </p>
    </section>
  );
}
