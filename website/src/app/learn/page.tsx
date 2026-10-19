import type { Metadata } from "next";
import { units, lessons, minutes, readings } from "@/lib/course";
import { CourseBrowser } from "@/components/CourseBrowser";
export const metadata: Metadata = {
  title: "Learn Go — the complete course",
  description:
    "Explore Go basics, concurrency, architecture, clean code, design patterns, Bash, Docker and Kubernetes. Full lessons, worked code and self-checks; no account.",
  alternates: { canonical: "/learn" },
};
export default function Learn() {
  return (
    <section className="page">
      <div className="page-intro">
        <p className="eyebrow">THE GO LEARNING LIBRARY</p>
        <h1>
          Understand the code.
          <br />
          <em>Then make it yours.</em>
        </h1>
        <p>
          From your first variable to architecture decisions. The same authored
          lessons as the app, with complete readings, highlighted examples and
          questions you can try here.
        </p>
        <div className="inline-stats">
          <span>
            <strong>{lessons.length}</strong> lessons & challenges
          </span>
          <span>
            <strong>{units.length}</strong> units
          </span>
          <span>
            <strong>{readings.length}</strong> deep readings
          </span>
        </div>
        <p className="availability">
          The library includes the expanded 1.1.3 course, available here now.
          The current App Store app is 1.1.2; these newer architecture lessons
          are coming to the app.
        </p>
      </div>
      <CourseBrowser
        items={lessons.map((l) => ({
          id: l.id,
          title: l.title,
          objective: l.objective,
          unitID: l.unitID,
          unitTitle: l.unitTitle,
          kind: l.kind,
          minutes: minutes(l),
        }))}
        groups={units.map((u) => ({ id: u.id, title: u.title }))}
      />
    </section>
  );
}
