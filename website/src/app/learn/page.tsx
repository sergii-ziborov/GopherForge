import Link from "next/link";
import { StructuredData } from "@/components/StructuredData";
import { releases } from "@/lib/releases";
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
          tooling lessons, matching App Store {releases.public.version}. Native{" "}
          {releases.next.version} with Continue is in TestFlight and waiting for
          App Review. Continue already saves your lesson and section in this
          browser. Web and app progress are stored separately.
        </p>
      </div>
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "Course",
          name: "Learn Go — the GopherForge course",
          description:
            "Go fundamentals, concurrency, architecture, design patterns, databases and production tooling.",
          provider: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          url: "https://gopherforge.app/learn",
          isAccessibleForFree: true,
          inLanguage: "en",
          hasPart: units.map((u) => ({
            "@type": "Course",
            name: u.title,
            url: `https://gopherforge.app/learn/units/${u.id}`,
          })),
        }}
      />
      <aside className="agent-study-callout">
        <p className="eyebrow">GO WITH CODING AGENTS</p>
        <p>
          Eight practical guides cover Codex, Claude, Cursor, API validation,
          security and concurrency review.{" "}
          <Link href="/interview/ai.workflow">Start the agent workflow →</Link>
        </p>
      </aside>
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
      <section className="unit-directory">
        <h2>Browse by subject.</h2>
        <p>Read each unit’s introduction and follow its lessons in order.</p>
        <nav aria-label="Course units">
          {units.map((u) => (
            <Link href={`/learn/units/${u.id}`} key={u.id}>
              {u.title} <span>{u.lessons.length} lessons →</span>
            </Link>
          ))}
        </nav>
      </section>
    </section>
  );
}
