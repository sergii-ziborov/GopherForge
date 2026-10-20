import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { dateLabel } from "@/lib/news";
import { posts } from "@/lib/posts";
import { lessonByID, lessonURL } from "@/lib/course";
import { Prose } from "@/components/Prose";
import { Code } from "@/components/Code";
export function generateStaticParams() {
  return posts.map((p) => ({ slug: p.slug }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const p = posts.find((p) => p.slug === slug);
  return {
    title: p?.title,
    description: p?.description,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: {
      type: "article",
      publishedTime: p?.date,
      authors: ["Serhii Ziborov"],
    },
  };
}
export default async function Article({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const p = posts.find((p) => p.slug === slug);
  if (!p) notFound();
  const related = p.related
    .map((id) => lessonByID.get(id))
    .filter((x) => x !== undefined);
  return (
    <article className="page article">
      <Link className="back" href="/blog">
        ← Field notes
      </Link>
      <header>
        <p className="eyebrow">
          {p.category} · {p.readingMinutes} MIN READ
        </p>
        <h1>{p.title}</h1>
        <p className="article-lede">{p.description}</p>
        <p className="article-byline">
          Serhii Ziborov · <time dateTime={p.date}>{dateLabel(p.date)}</time>
        </p>
      </header>
      {p.sections.map((s, i) => (
        <section className="reading-section" key={s.title}>
          <span className="section-number">
            {String(i + 1).padStart(2, "0")}
          </span>
          <h2>{s.title}</h2>
          <Prose>{s.body}</Prose>
          {s.code ? <Code code={s.code} language={s.language} /> : null}
        </section>
      ))}
      <section className="references">
        <h2>Sources & further reading</h2>
        <ul>
          {p.references.map((url) => (
            <li key={url}>
              <a href={url} rel="noopener noreferrer">
                {url.replace("https://", "")}
              </a>
            </li>
          ))}
        </ul>
      </section>
      {related.length ? (
        <section className="related">
          <p className="eyebrow">KEEP LEARNING</p>
          <h2>Put the idea into practice.</h2>
          {related.map((l) => (
            <Link key={l.id} href={lessonURL(l.id)}>
              {l.title}
              <span aria-hidden="true">→</span>
            </Link>
          ))}
        </section>
      ) : null}
      <Link href="/blog" className="back">
        ← All field notes
      </Link>
    </article>
  );
}
