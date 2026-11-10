import { pageMetadata } from "@/lib/page-metadata";
import Link from "next/link";
import type { Metadata } from "next";
import { posts } from "@/lib/posts";
import { news, newsURL, newsImage, dateLabel } from "@/lib/news";
export const metadata: Metadata = pageMetadata(
  "/blog",
  "Field notes — practical Go articles",
  "Practical Go guides: generics, Redis caching, MongoDB, OpenTelemetry, fuzz testing and offline web assets, with tested examples and illustrated explanations.",
);
export default function Blog() {
  return (
    <section className="page">
      <div className="page-intro">
        <p className="eyebrow">FIELD NOTES</p>
        <h1>
          Ideas worth
          <br />
          <em>putting to work.</em>
        </h1>
        <p>
          Practical notes on building with Go. Real constraints, useful
          examples, and a path into the course when you want to go deeper.
        </p>
      </div>
      <section className="section-space" aria-labelledby="journal-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">FROM THE GO JOURNAL</p>
            <h2 id="journal-heading">Recent engineering guides.</h2>
          </div>
          <Link href="/news" className="text-link">
            Browse all {news.length} articles ↗
          </Link>
        </div>
        <div className="blog-grid">
          {news.slice(0, 6).map((n) => {
            const im = newsImage(n.imagePrefix + "-hero");
            return (
              <Link className="blog-tile" key={n.slug} href={newsURL(n.slug)}>
                <img
                  className="journal-teaser-image"
                  src={im.src}
                  width={im.width}
                  height={im.height}
                  alt=""
                  loading="lazy"
                />
                <p className="card-meta">
                  EDITION {dateLabel(n.editionDate)} ·{" "}
                  {Math.ceil(n.wordCount / 200)} min read
                </p>
                <h3>{n.title}</h3>
                <p>{n.description}</p>
                <span>Read the guide →</span>
              </Link>
            );
          })}
        </div>
      </section>
      <h2 className="section-space">Field notes and foundations.</h2>
      <div className="post-list">
        {posts.map((p, i) => (
          <Link key={p.slug} className="post-card" href={`/blog/${p.slug}`}>
            <span className="post-index">{String(i + 1).padStart(2, "0")}</span>
            <div>
              <p className="card-meta">
                {p.category} · {p.readingMinutes} min read
              </p>
              <h2>{p.title}</h2>
              <p>{p.description}</p>
            </div>
            <span className="post-arrow" aria-hidden="true">
              ↗
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
