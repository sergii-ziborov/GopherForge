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
    <section className="page learn-map-page">
      <div className="page-intro course-map-intro">
        <p className="eyebrow">THE GO LEARNING LIBRARY</p>
        <h1>
          Your Go <em>learning map.</em>
        </h1>
        <p>
          Choose a direction, open a branch, and follow the lessons in order —
          or go straight to the topic you need.
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
          The web library includes the latest MongoDB, Redis and production
          tooling lessons. These additions are being prepared for native 1.1.4.
          See the version history for App Store and TestFlight availability.
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
        groups={units.map((u) => ({
          id: u.id,
          title: u.title,
          summary: u.summary,
        }))}
      />
    </section>
  );
}
