"use client";
import { useEffect, useState } from "react";
import {
  readAssessments,
  saveAssessment,
  studyEvent,
  type Assessment,
} from "@/lib/study";
export function InterviewAssessment({ id }: { id: string }) {
  const [mark, setMark] = useState("");
  const [message, setMessage] = useState("");
  useEffect(() => {
    const refresh = () => setMark(readAssessments()[id] ?? "");
    refresh();
    window.addEventListener(studyEvent, refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener(studyEvent, refresh);
      window.removeEventListener("storage", refresh);
    };
  }, [id]);
  function save(next: Assessment | "") {
    const saved = saveAssessment(id, next);
    setMark(next);
    setMessage(
      saved
        ? "Saved in this browser."
        : "Browser storage unavailable; kept for this page only.",
    );
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
