import type { Metadata } from "next";
import Link from "next/link";
import { news, newsURL, newsImage, dateLabel } from "@/lib/news";
import { StructuredData } from "@/components/StructuredData";
export const metadata: Metadata = {
  title: "Go News — releases, tooling and practical analysis",
  description:
    "Original Go news and practical engineering analysis from GopherForge. Follow Go releases, gopls, editor tools and cloud-native development.",
  alternates: {
    canonical: "/news",
    types: { "application/rss+xml": "/news/rss.xml" },
  },
  openGraph: {
    title: "Go News — GopherForge",
    description:
      "Go releases explained through practical examples and engineering decisions.",
    url: "/news",
    images: ["/images/news/launch-hero.webp"],
  },
};
export default function NewsPage() {
  return (
    <div className="page news-page">
      <header className="news-heading">
        <p className="eyebrow">THE GOPHERFORGE JOURNAL</p>
        <h1>
          News.
          <br />
          <em>Then the next useful step.</em>
        </h1>
        <p className="article-lede">
          Go releases, tools and the decisions behind them. Original reporting
          from primary sources, with examples you can use.
        </p>
        <nav className="news-tabs" aria-label="News sections">
          <Link href="/news" aria-current="page">
            Our analysis <span>{String(news.length).padStart(2, "0")}</span>
          </Link>
          <Link href="/news/feed">From the Go community ↗</Link>
          <a href="/news/rss.xml">RSS</a>
        </nav>
      </header>
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "CollectionPage",
          name: "GopherForge Go News",
          url: "https://gopherforge.app/news",
          mainEntity: {
            "@type": "ItemList",
            itemListElement: news.map((n, i) => ({
              "@type": "ListItem",
              position: i + 1,
              url: `https://gopherforge.app${newsURL(n.slug)}`,
              name: n.title,
            })),
          },
        }}
      />
      <div className="news-grid">
        {news.map((n, i) => {
          const im = newsImage(n.imagePrefix + "-hero");
          return (
            <article
              className={`news-card ${i === 0 ? "news-featured" : ""}`}
              key={n.slug}
            >
              <Link
                href={newsURL(n.slug)}
                className="news-picture"
                tabIndex={-1}
                aria-hidden="true"
              >
                <img
                  src={im.src.replace(".webp", "-small.webp")}
                  width={im.width}
                  height={im.height}
                  alt=""
                  loading={i === 0 ? "eager" : "lazy"}
                />
              </Link>
              <div className="news-card-copy">
                <p className="card-meta">
                  {n.category} · EDITION {dateLabel(n.editionDate)}
                </p>
                <h2>
                  <Link href={newsURL(n.slug)}>{n.title}</Link>
                </h2>
                <p>{n.description}</p>
                <p className="small-note">
                  {Math.ceil(n.wordCount / 200)} min read · GopherForge
                  editorial
                </p>
                <Link className="text-link" href={newsURL(n.slug)}>
                  Read the analysis <span aria-hidden="true">→</span>
                </Link>
              </div>
            </article>
          );
        })}
      </div>
      <aside className="news-callout">
        <div>
          <p className="eyebrow">A DIFFERENT SHELF</p>
          <h2>The original voices, in full.</h2>
          <p>
            Read complete licensed articles from The Go Blog in our separate
            community reader. Authors, dates and source credits stay attached.
          </p>
        </div>
        <Link className="button" href="/news/feed">
          Open the community feed →
        </Link>
      </aside>
    </div>
  );
}
