import type { Metadata } from "next";
import Link from "next/link";
import { news, newsURL, newsImage, dateLabel } from "@/lib/news";
import {
  newsPageBounds,
  newsPageCount,
  newsPageURL,
} from "@/lib/news-pagination";
import { StructuredData } from "@/components/StructuredData";
import { NewsArchive } from "@/components/NewsArchive";

export function newsListingMetadata(page: number): Metadata {
  const title =
    page === 1
      ? "Go News — releases, tooling and practical analysis"
      : `Go News — page ${page} of ${newsPageCount(news.length)}`;
  const description =
    page === 1
      ? "Original Go news and practical engineering analysis from GopherForge. Follow Go releases, gopls, editor tools and cloud-native development."
      : `Page ${page} of the GopherForge Go archive: practical engineering guides, release analysis and tested examples. Browse older editions and keep learning.`;
  const path = newsPageURL(page);
  const bounds = newsPageBounds(news.length, page);
  const first = news[bounds?.start ?? 0];
  return {
    title,
    description,
    alternates: {
      canonical: path,
      types: { "application/rss+xml": "/news/rss.xml" },
    },
    openGraph: {
      title,
      description,
      url: path,
      images: [newsImage(first.imagePrefix + "-hero").src],
    },
  };
}

export function NewsListing({ page = 1 }: { page?: number }) {
  const bounds = newsPageBounds(news.length, page)!;
  const visible = news.slice(bounds.start, bounds.end);
  const cards = news.map((n) => {
    const { src, width, height } = newsImage(n.imagePrefix + "-hero");
    return {
      url: newsURL(n.slug),
      title: n.title,
      description: n.description,
      category: n.category,
      edition: dateLabel(n.editionDate),
      minutes: Math.ceil(n.wordCount / 200),
      image: { src, width, height },
    };
  });
  return (
    <div className="page news-page">
      <header className="news-heading">
        <p className="eyebrow">
          THE GOPHERFORGE JOURNAL{page > 1 ? ` · PAGE ${page}` : ""}
        </p>
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
          name:
            page === 1
              ? "GopherForge Go News"
              : `GopherForge Go News — page ${page}`,
          url: "https://gopherforge.app" + newsPageURL(page),
          mainEntity: {
            "@type": "ItemList",
            numberOfItems: visible.length,
            itemListElement: visible.map((n, i) => ({
              "@type": "ListItem",
              position: bounds.start + i + 1,
              url: "https://gopherforge.app" + newsURL(n.slug),
              name: n.title,
            })),
          },
        }}
      />
      <NewsArchive key={page} items={cards} initialPage={page} />
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
