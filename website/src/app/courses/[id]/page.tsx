import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { appStore, lessonURL, minutes, units } from "@/lib/course";
import { Breadcrumbs, StructuredData } from "@/components/StructuredData";
import {
  courseImageURL,
  courseURL,
  specializedAvailability,
  specializedCourses,
  specializedReviewedOn,
} from "@/lib/specialized-courses";

export const dynamicParams = false;
export function generateStaticParams() {
  return specializedCourses.map((c) => ({ id: c.id }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const c = specializedCourses.find((c) => c.id === id);
  if (!c) return { title: "Course not found" };
  return {
    title: c.seoTitle,
    description: c.description,
    keywords: c.keywords,
    alternates: { canonical: courseURL(id) },
    // The share image comes from this segment's opengraph-image.tsx.
    openGraph: {
      title: `${c.seoTitle} — GopherForge`,
      description: c.description,
      url: courseURL(id),
      siteName: "GopherForge",
      type: "website",
    },
  };
}

export default async function Course({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const c = specializedCourses.find((c) => c.id === id);
  if (!c) notFound();
  const first = c.courseUnits[0].lessons[0];
  const hours = (lessons: typeof first[]) =>
    Math.max(1, Math.round(lessons.reduce((n, l) => n + minutes(l), 0) / 60));
  const related = c.related
    .map((u) => units.find((x) => x.id === u))
    .filter((u) => u !== undefined);
  return (
    <article className="page article">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "Dedicated courses", path: "/courses" },
          { name: c.title, path: courseURL(id) },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "Course",
          name: c.title,
          description: c.description,
          url: "https://gopherforge.app" + courseURL(id),
          provider: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          isAccessibleForFree: true,
          inLanguage: "en",
          image: "https://gopherforge.app" + courseImageURL(id),
          dateModified: specializedReviewedOn,
          educationalLevel: "Intermediate",
          coursePrerequisites: c.prerequisites,
          keywords: c.keywords.join(", "),
          teaches: c.outcomes,
          syllabusSections: c.courseUnits.map((u) => ({
            "@type": "Syllabus",
            name: u.title,
            description: u.summary,
            timeRequired: `PT${hours(u.lessons)}H`,
          })),
          offers: {
            "@type": "Offer",
            category: "Free",
            price: 0,
            priceCurrency: "USD",
          },
          hasCourseInstance: {
            "@type": "CourseInstance",
            courseMode: "Online",
            courseWorkload: `PT${hours(c.courseUnits.flatMap((u) => u.lessons))}H`,
          },
          hasPart: c.courseUnits.flatMap((u) =>
            u.lessons.map((l) => ({
              "@type": "LearningResource",
              name: l.title,
              url: "https://gopherforge.app" + lessonURL(l.id),
            })),
          ),
        }}
      />
      <Link href="/courses" className="back">
        ← Dedicated courses
      </Link>
      <header>
        <p className="eyebrow">
          {c.eyebrow} · {c.lessonCount} LESSONS
        </p>
        <h1>{c.title}</h1>
        <p className="article-lede">{c.lede}</p>
        <p>
          <Link className="button primary" href={lessonURL(first.id)}>
            Start with “{first.title}” →
          </Link>
        </p>
      </header>
      <section className="reading-section">
        <h2>Who it is for</h2>
        <p>{c.audience}</p>
        <h2>Before you start</h2>
        <p>{c.prerequisites}</p>
        <h2>What you will be able to do</h2>
        <ul>
          {c.outcomes.map((o) => (
            <li key={o}>{o}</li>
          ))}
        </ul>
      </section>
      {c.courseUnits.map((u, index) => (
        <section key={u.id} className="reading-section">
          <h2>
            Unit {index + 1}. {u.title}
          </h2>
          <p>{u.summary}</p>
          <ol className="unit-directory-lessons">
            {u.lessons.map((l) => (
              <li key={l.id}>
                <Link href={lessonURL(l.id)}>
                  <h3>{l.title}</h3>
                </Link>
                <p>{l.objective}</p>
                <p className="small-note">{minutes(l)} min · Worked lesson</p>
              </li>
            ))}
          </ol>
          <p className="small-note">
            <Link href={`/learn/units/${u.id}`}>Unit page →</Link>
          </p>
        </section>
      ))}
      <aside className="news-callout">
        <div>
          <h2>Study it on iPhone and iPad.</h2>
          <p>{specializedAvailability}</p>
        </div>
        <a href={appStore} className="button">
          GopherForge on the App Store →
        </a>
      </aside>
      {related.length > 0 && (
        <p>
          Related:{" "}
          {related.map((u, i) => (
            <span key={u.id}>
              {i > 0 && " · "}
              <Link href={`/learn/units/${u.id}`}>{u.title}</Link>
            </span>
          ))}
        </p>
      )}
    </article>
  );
}
