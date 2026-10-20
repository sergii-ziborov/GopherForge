import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { externalFeed } from "@/lib/external-news";
import { dateLabel } from "@/lib/news";
export const dynamic = "force-dynamic";
export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const e = (await externalFeed()).entries.find((e) => e.id === id);
  return {
    title: e?.title ?? "Article not found",
    description: e?.excerpt,
    robots: { index: false, follow: true },
    alternates: e ? { canonical: e.sourceURL } : undefined,
  };
}
export default async function ExternalReader({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const e = (await externalFeed()).entries.find((e) => e.id === id);
  if (!e) notFound();
  // The Atom body includes the publisher's page header as well as the article.
  // Keep the complete article, with the single attributed header shown above.
  const body = [...e.blocks];
  while (
    body.length &&
    ["h2", "h3"].includes(body[0].kind) &&
    ["The Go Blog", e.title].includes(body[0].text.trim())
  )
    body.shift();
  if (
    body[0]?.kind === "p" &&
    body[0].text.includes(e.author) &&
    body[0].text.length < e.author.length + 65
  )
    body.shift();
  return (
    <article className="page article external-reader">
      <Link className="back" href="/news/feed">
        ← Community reader
      </Link>
      <header>
        <p className="eyebrow">EXTERNAL · THE GO BLOG · FULL FEED TEXT</p>
        <h1>{e.title}</h1>
        <p className="article-byline">
          {e.author} ·{" "}
          <time dateTime={e.publishedAt}>{dateLabel(e.publishedAt)}</time> ·{" "}
          {Math.ceil(e.wordCount / 200)} min read
        </p>
      </header>
      <aside className="feed-license">
        <strong>Republished under {e.license}.</strong>
        <p>
          Complete text supplied by the publisher’s Atom feed. Formatting is
          adapted; embedded media is omitted and image descriptions are
          retained. This is the original author’s article, separate from
          GopherForge analysis. <a href={e.sourceURL}>Original article</a> ·{" "}
          <a href={e.licenseURL}>Licence</a> ·{" "}
          <a href={e.licenseEvidence}>Publisher’s terms</a>. No endorsement is
          implied.
        </p>
      </aside>
      <div className="external-body">
        {body.map((b, i) =>
          b.kind === "pre" ? (
            <pre key={i}>
              <code>{b.text}</code>
            </pre>
          ) : b.kind === "h2" ? (
            <h2 key={i}>{b.text}</h2>
          ) : b.kind === "h3" ? (
            <h3 key={i}>{b.text}</h3>
          ) : b.kind === "li" ? (
            <p className="external-list-item" key={i}>
              • {b.text}
            </p>
          ) : (
            <p key={i}>{b.text}</p>
          ),
        )}
      </div>
      <section className="references">
        <h2>Links from the original article</h2>
        <ul>
          {e.links.map((url, i) => (
            <li key={i}>
              <a href={url}>{url}</a>
            </li>
          ))}
        </ul>
      </section>
      <section className="references">
        <h2>Source & permissions</h2>
        <p>
          © The Go Authors. Article text:{" "}
          <a href={e.licenseURL}>Creative Commons Attribution 4.0</a>. Source:{" "}
          <a href={e.sourceURL}>{e.title}</a>, by {e.author}. Layout and
          formatting adapted by GopherForge; third-party embedded media is not
          republished. Code examples are covered by the{" "}
          <a href="/licenses/go-code.txt">Go BSD licence and disclaimer</a>.
        </p>
      </section>
      <Link className="button" href="/news">
        Read GopherForge analysis →
      </Link>
    </article>
  );
}
