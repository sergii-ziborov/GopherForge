import type { Metadata } from "next";
import Link from "next/link";
import { externalFeed } from "@/lib/external-news";
import { dateLabel } from "@/lib/news";
export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Go community news — full articles from The Go Blog",
  description:
    "Read complete licensed Go Blog articles with code, author credits and source references. A separate community feed checked twice daily.",
  alternates: { canonical: "/news/feed" },
};
export default async function Feed() {
  const f = await externalFeed();
  const stale = Date.now() - Date.parse(f.checkedAt) > 36 * 3600 * 1000;
  return (
    <div className="page news-page">
      <header className="news-heading">
        <p className="eyebrow">FROM THE GO COMMUNITY</p>
        <h1>
          The original voices.
          <br />
          <em>Room to read.</em>
        </h1>
        <p className="article-lede">
          Full articles from The Go Blog, with code and explanations. A separate
          shelf from our own reporting.
        </p>
        <nav className="news-tabs" aria-label="News sections">
          <Link href="/news">Our analysis</Link>
          <Link href="/news/feed" aria-current="page">
            Community reader
          </Link>
        </nav>
      </header>
      <aside className="feed-status">
        <strong>
          {f.cacheStatus === "fallback"
            ? "Saved edition"
            : f.refreshFailed || stale
              ? "Last successful edition"
              : "Feed connected"}
        </strong>
        <span>
          Last successful check:{" "}
          <time dateTime={f.checkedAt}>
            {new Date(f.checkedAt).toLocaleString("en-GB", { timeZone: "UTC" })}{" "}
            UTC
          </time>
          . Checks scheduled twice daily; new articles appear when the publisher
          releases them.
          {f.refreshFailed || stale
            ? " The latest refresh is delayed; saved articles remain readable."
            : ""}
        </span>
      </aside>
      <div className="feed-list">
        {f.entries.map((e) => (
          <article key={e.id} className="feed-card">
            <div className="feed-source">
              <span aria-hidden="true">G↗</span>
              <p>
                The Go Blog<small>{dateLabel(e.publishedAt)}</small>
              </p>
            </div>
            <div>
              <p className="card-meta">
                EXTERNAL · FULL FEED TEXT · {e.license}
              </p>
              <h2>
                <Link href={"/news/feed/" + e.id}>{e.title}</Link>
              </h2>
              <p>{e.excerpt}</p>
              <p className="small-note">
                By {e.author} · {e.wordCount.toLocaleString("en-US")} words ·{" "}
                {Math.ceil(e.wordCount / 200)} min read
              </p>
              <Link className="text-link" href={"/news/feed/" + e.id}>
                Read the full article →
              </Link>
            </div>
          </article>
        ))}
      </div>
      <aside className="news-callout">
        <div>
          <h2>Keep a personal reading list.</h2>
          <p>
            Member reading lists and source-link access for other publishers
            will open after registration becomes available. Accounts are coming
            soon; no sign-up is required for these licensed articles.
          </p>
          <p className="small-note">
            Go Blog originals remain linked for attribution under their
            republication licence. Other publishers are not copied without
            permission.
          </p>
        </div>
        <Link className="button secondary" href="/register?from=news">
          Preview registration →
        </Link>
      </aside>
    </div>
  );
}
