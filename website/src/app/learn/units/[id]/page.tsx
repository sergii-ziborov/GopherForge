import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { units, lessonURL, minutes } from "@/lib/course";
import { Breadcrumbs, StructuredData } from "@/components/StructuredData";
export const dynamicParams = false;
export function generateStaticParams() {
  return units.map((u) => ({ id: u.id }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const u = units.find((u) => u.id === id);
  return {
    title: u ? `${u.title} — Go lessons and worked examples` : "Unit not found",
    description: u?.summary,
    alternates: { canonical: `/learn/units/${id}` },
    openGraph: {
      title: u?.title,
      description: u?.summary,
      url: `/learn/units/${id}`,
    },
  };
}
export default async function Unit({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const u = units.find((u) => u.id === id);
  if (!u) notFound();
  return (
    <article className="page article">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "Learn Go", path: "/learn" },
          { name: u.title, path: `/learn/units/${id}` },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "Course",
          name: u.title,
          description: u.summary,
          url: `https://gopherforge.app/learn/units/${id}`,
          provider: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          isAccessibleForFree: true,
          inLanguage: "en",
          hasPart: u.lessons.map((l) => ({
            "@type": "LearningResource",
            name: l.title,
            url: "https://gopherforge.app" + lessonURL(l.id),
          })),
        }}
      />
      <Link href="/learn" className="back">
        ← Course map
      </Link>
      <header>
        <p className="eyebrow">GO LEARNING PATH · {u.lessons.length} LESSONS</p>
        <h1>{u.title}</h1>
        <p className="article-lede">{u.summary}</p>
      </header>
      <ol className="unit-directory-lessons">
        {u.lessons.map((l) => (
          <li key={l.id}>
            <Link href={lessonURL(l.id)}>
              <h2>{l.title}</h2>
            </Link>
            <p>{l.objective}</p>
            <p className="small-note">
              {minutes(l)} min ·{" "}
              {l.kind === "predict" ? "Prediction challenge" : "Worked lesson"}
            </p>
          </li>
        ))}
      </ol>
      <aside className="news-callout">
        <div>
          <h2>Pick up where you paused.</h2>
          <p>
            Continue remembers your last lesson and section in this browser. No
            account is required; web and native app progress remain separate.
          </p>
        </div>
        <Link href={`/learn?unit=${id}`} className="button">
          Open this branch →
        </Link>
      </aside>
    </article>
  );
}
