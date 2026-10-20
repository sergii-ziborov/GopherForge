"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { readStudy, studyEvent, studyURL, type Study } from "@/lib/study";
import { readProgress } from "@/lib/progress";
export function StudyContinue({
  course,
  interview,
}: {
  course: { id: string; title: string }[];
  interview: { id: string; title: string }[];
}) {
  const [study, setStudy] = useState<Study | null>(null);
  useEffect(() => {
    const refresh = () => {
      const state = readStudy();
      const legacy = readProgress().last;
      setStudy(
        state.area
          ? state
          : {
              ...state,
              area: legacy ? "course" : null,
              course: legacy ? { id: legacy, section: "" } : null,
            },
      );
    };
    refresh();
    window.addEventListener(studyEvent, refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener(studyEvent, refresh);
      window.removeEventListener("storage", refresh);
    };
  }, []);
  if (!study?.area) return null;
  const bookmark = study[study.area];
  const item = (study.area === "course" ? course : interview).find(
    (item) => item.id === bookmark?.id,
  );
  if (!bookmark || !item) return null;
  return (
    <section className="page home-continue" aria-label="Your saved place">
      <div className="progress-summary">
        <div>
          <p className="eyebrow">
            YOUR SAVED PLACE ·{" "}
            {study.area === "course" ? "LEARN GO" : "INTERVIEW"}
          </p>
          <strong>{item.title}</strong>
          <p>Saved on this browser. Pick up where you left off.</p>
        </div>
        <Link
          className="button secondary"
          href={studyURL(study.area, bookmark)}
        >
          Continue learning →
        </Link>
      </div>
    </section>
  );
}
