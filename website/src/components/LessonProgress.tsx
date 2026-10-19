"use client";
import { useEffect, useState } from "react";
import { readProgress, saveProgress } from "@/lib/progress";
export function LessonProgress({ id }: { id: string }) {
  const [done, setDone] = useState(false);
  const [message, setMessage] = useState("");
  useEffect(() => {
    const p = readProgress();
    setDone(p.completed.includes(id));
    saveProgress({ ...p, last: id });
  }, [id]);
  function toggle() {
    const p = readProgress();
    const next = !done;
    const saved = saveProgress({
      ...p,
      last: id,
      completed: next
        ? [...new Set([...p.completed, id])]
        : p.completed.filter((x) => x !== id),
    });
    setDone(next);
    setMessage(
      !saved
        ? "Browser storage is unavailable. This mark is kept for this page only."
        : next
          ? "Saved on this browser. You can continue to the next lesson."
          : "Marked as not completed.",
    );
  }
  return (
    <div className="completion">
      <button
        className={done ? "button secondary" : "button"}
        type="button"
        onClick={toggle}
      >
        {done ? "✓ Completed · undo" : "Mark lesson complete"}
      </button>
      <p role="status">
        {message || "Progress stays in this browser. No account needed."}
      </p>
    </div>
  );
}
