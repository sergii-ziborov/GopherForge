import Link from "next/link";
import type { Metadata } from "next";
import { posts } from "@/lib/posts";
export const metadata: Metadata = {
  title: "Field notes — practical Go articles",
  description:
    "Guides to Go architecture, clean code, package limits, Kubernetes diagnostics and learning with the workbench.",
  alternates: { canonical: "/blog" },
};
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
