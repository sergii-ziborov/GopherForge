"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import {
  NEWS_PAGE_SIZE,
  newsPageBounds,
  newsPageCount,
  newsPageURL,
  type NewsCard,
} from "@/lib/news-pagination";

export function NewsArchive({
  items,
  initialPage,
}: {
  items: NewsCard[];
  initialPage: number;
}) {
  const { start, end } = newsPageBounds(items.length, initialPage)!;
  const [visibleCount, setVisibleCount] = useState(end - start);
  const sentinel = useRef<HTMLDivElement>(null);
  const grid = useRef<HTMLDivElement>(null);
  const pendingFocus = useRef<number | null>(null);
  const available = items.length - start;
  const hasMore = visibleCount < available;
  const nextCount = Math.min(visibleCount + NEWS_PAGE_SIZE, available);
  const nextPage = Math.floor((start + visibleCount) / NEWS_PAGE_SIZE) + 1;

  useEffect(() => {
    if (
      !hasMore ||
      !sentinel.current ||
      typeof IntersectionObserver === "undefined"
    )
      return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          observer.disconnect();
          setVisibleCount(nextCount);
        }
      },
      { rootMargin: "240px 0px" },
    );
    observer.observe(sentinel.current);
    return () => observer.disconnect();
  }, [hasMore, nextCount]);

  useEffect(() => {
    if (pendingFocus.current === null) return;
    grid.current
      ?.querySelector<HTMLAnchorElement>(
        `[data-news-index="${pendingFocus.current}"]`,
      )
      ?.focus();
    pendingFocus.current = null;
  }, [visibleCount]);

  return (
    <>
      <div className="news-grid" ref={grid}>
        {items.slice(start, start + visibleCount).map((n, i) => (
          <article
            className={`news-card ${start + i === 0 ? "news-featured" : ""}`}
            key={n.url}
          >
            <Link
              href={n.url}
              className="news-picture"
              tabIndex={-1}
              aria-hidden="true"
            >
              <img
                {...n.image}
                alt=""
                loading={i === 0 ? "eager" : "lazy"}
                decoding="async"
              />
            </Link>
            <div className="news-card-copy">
              <p className="card-meta">
                {n.category} · EDITION {n.edition}
              </p>
              <h2>
                <Link href={n.url} data-news-index={start + i}>
                  {n.title}
                </Link>
              </h2>
              <p>{n.description}</p>
              <p className="small-note">
                {n.minutes} min read · GopherForge editorial
              </p>
              <Link className="text-link" href={n.url}>
                Read the analysis <span aria-hidden="true">→</span>
              </Link>
            </div>
          </article>
        ))}
      </div>
      <div className="news-archive-progress" ref={sentinel}>
        <p
          className="small-note"
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          Showing {start + 1}–{start + visibleCount} of {items.length} articles
        </p>
        {hasMore ? (
          <a
            className="button secondary"
            href={newsPageURL(nextPage)}
            onClick={(event) => {
              if (
                event.metaKey ||
                event.ctrlKey ||
                event.shiftKey ||
                event.altKey ||
                event.button !== 0
              )
                return;
              event.preventDefault();
              pendingFocus.current = start + visibleCount;
              setVisibleCount(nextCount);
            }}
          >
            Show {nextCount - visibleCount} more articles ↓
          </a>
        ) : (
          <p className="small-note">You’ve reached the end of the archive.</p>
        )}
      </div>
      <nav className="news-pagination" aria-label="News archive pages">
        {initialPage > 1 && (
          <a href={newsPageURL(initialPage - 1)} rel="prev">
            ← Newer
          </a>
        )}
        {Array.from(
          { length: newsPageCount(items.length) },
          (_, i) => i + 1,
        ).map((page) => (
          <a
            key={page}
            href={newsPageURL(page)}
            aria-label={`Page ${page}`}
            aria-current={page === initialPage ? "page" : undefined}
          >
            {page}
          </a>
        ))}
        {initialPage < newsPageCount(items.length) && (
          <a href={newsPageURL(initialPage + 1)} rel="next">
            Older →
          </a>
        )}
      </nav>
    </>
  );
}
