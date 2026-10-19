"use client";
import { useState } from "react";
import type { Quiz as QuizType } from "@/lib/course";
export function Quiz({ quiz, id }: { quiz: QuizType; id: string }) {
  const [selected, setSelected] = useState<string | null>(null);
  const [hint, setHint] = useState(false);
  const options = [quiz.correct, ...quiz.alternatives];
  const offset = [...id].reduce((n, c) => n + c.charCodeAt(0), 0) % 3;
  const ordered = [...options.slice(offset), ...options.slice(0, offset)];
  const correct = selected === quiz.correct;
  return (
    <section className="quiz" aria-labelledby="quiz-heading">
      <p className="eyebrow">Check your understanding</p>
      <h2 id="quiz-heading">{quiz.question}</h2>
      <div className="answers">
        {ordered.map((a) => (
          <button
            type="button"
            key={a}
            className={`answer ${selected === a ? (correct ? "correct" : "incorrect") : ""}`}
            onClick={() => setSelected(a)}
            disabled={correct}
          >
            {a}
          </button>
        ))}
      </div>
      {selected ? (
        <div role="status" className={`feedback ${correct ? "good" : ""}`}>
          <strong>{correct ? "Correct." : "Not quite. Try again."}</strong>
          <p>{quiz.explanation}</p>
        </div>
      ) : null}
      <button
        className="text-button"
        type="button"
        onClick={() => setHint(!hint)}
        aria-expanded={hint}
      >
        {hint ? "Hide hint" : "Show a hint"}
      </button>
      {hint ? <p>{quiz.hint}</p> : null}
    </section>
  );
}
