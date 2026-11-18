import Link from "next/link";
import { pageMetadata } from "@/lib/page-metadata";
import { Breadcrumbs, StructuredData } from "@/components/StructuredData";
import { lessonURL } from "@/lib/course";
import {
  courseURL,
  specializedAvailability,
  specializedCourses,
} from "@/lib/specialized-courses";

export const metadata = pageMetadata(
  "/courses",
  "Dedicated Go courses: Gin, blockchain, security and game development",
  `Four free, code-first Go courses with ${specializedCourses.reduce((n, c) => n + c.lessonCount, 0)} worked lessons: a Gin tutorial from first route to REST API, blockchain infrastructure, secure services and game development.`,
);

export default function Courses() {
  return (
    <section className="page learn-map-page">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "Dedicated courses", path: "/courses" },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "ItemList",
          name: "GopherForge dedicated Go courses",
          itemListElement: specializedCourses.map((c, index) => ({
            "@type": "ListItem",
            position: index + 1,
            url: "https://gopherforge.app" + courseURL(c.id),
            name: c.title,
          })),
        }}
      />
      <header className="page-intro">
        <p className="eyebrow">DEDICATED COURSES</p>
        <h1>
          Go, applied. <em>Four focused courses.</em>
        </h1>
        <p>
          Each course is a path of worked lessons with runnable Go examples,
          self-checks and references. Start at the first lesson or jump to the
          unit you need; nothing is locked.
        </p>
        <p className="availability">{specializedAvailability}</p>
      </header>
      <div className="download-grid">
        {specializedCourses.map((c) => (
          <section className="download-card" key={c.id}>
            <p className="eyebrow">{c.eyebrow}</p>
            <h2>
              <Link href={courseURL(c.id)}>{c.title}</Link>
            </h2>
            <p>{c.description}</p>
            <p>
              {c.courseUnits.length} units · {c.lessonCount} lessons
            </p>
            <p>
              <Link className="button primary" href={courseURL(c.id)}>
                Open the course →
              </Link>{" "}
              <Link href={lessonURL(c.courseUnits[0].lessons[0].id)}>
                Start lesson 1
              </Link>
            </p>
          </section>
        ))}
      </div>
      <p>
        Looking for the Go language itself? The{" "}
        <Link href="/learn">Go learning map</Link> covers fundamentals,
        concurrency, architecture, patterns, data stores and DevOps.
      </p>
    </section>
  );
}
