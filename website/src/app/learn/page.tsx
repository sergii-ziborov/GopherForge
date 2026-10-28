import Link from "next/link";
import { interview } from "@/lib/interview";
import { ProgressTransfer } from "@/components/ProgressTransfer";
import { curriculumUpdatedOn } from "@/lib/curriculum-revision";
import { StructuredData } from "@/components/StructuredData";
import { releases } from "@/lib/releases";
import type { Metadata } from "next";
import { units, lessons, minutes, readings } from "@/lib/course";
import { CourseBrowser } from "@/components/CourseBrowser";
import { EditorialIllustration } from "@/components/EditorialIllustration";
export const metadata: Metadata = {
  title: "Learn Go — the complete course",
  description:
    "Learn Go with 186 teaching lessons: concurrency, JSON v2, architecture, SQL, MongoDB, Redis, coding agents and deployment. Worked code and self-checks; no account.",
  alternates: { canonical: "/learn" },
};
export default function Learn() {
  return (
    <section className="page learn-map-page">
      <header className="page-intro course-map-intro illustrated-intro">
        <div className="intro-overview">
          <div className="intro-copy">
            <p className="eyebrow">THE GO LEARNING LIBRARY</p>
            <h1>
              Your Go <em>learning map.</em>
            </h1>
            <p>
              Choose a direction, open a branch, and follow the lessons in order
              — or go straight to the topic you need.
            </p>
          </div>
          <EditorialIllustration
            id="launch-hero"
            alt="Gopher reading beneath a branching tree of Go concepts."
            loading="eager"
          />
        </div>
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
          The web library includes JSON v2, modern concurrency, SQL services and
          coding-agent lessons prepared for native {releases.next.version}. App
          Store {releases.public.version} includes Continue. See{" "}
          <Link href="/updates">version history</Link> for release status.
          Continue saves your lesson and section in this browser. Web and app
          progress are stored separately.
        </p>
      </header>
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
          Four course readings and eight interview guides cover Codex, Claude
          Code, Cursor, repository instructions, API validation and trust
          boundaries.{" "}
          <Link href="/learn/ai.go-workflow">Start the agent workflow →</Link>
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
      <ProgressTransfer
        lessons={lessons.map((l) => l.id)}
        interview={interview.questions.map((q) => q.id)}
        revision={curriculumUpdatedOn}
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
