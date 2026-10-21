import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { news, newsURL, newsImage, dateLabel, imageCaption } from "@/lib/news";
import { Prose } from "@/components/Prose";
import { StructuredData, Breadcrumbs } from "@/components/StructuredData";
export const dynamicParams = false;
export function generateStaticParams() {
  return news.map((n) => ({ slug: n.slug }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const n = news.find((n) => n.slug === slug);
  if (!n) return {};
  return {
    title: n.title,
    description: n.description,
    keywords: n.keywords,
    alternates: { canonical: newsURL(slug) },
    openGraph: {
      type: "article",
      title: n.title,
      description: n.description,
      url: newsURL(slug),
      publishedTime: n.publishedAt,
      modifiedTime: n.modifiedAt,
      authors: ["GopherForge editorial"],
      images: [
        {
          url: newsImage(n.imagePrefix + "-hero").src,
          width: newsImage(n.imagePrefix + "-hero").width,
          height: newsImage(n.imagePrefix + "-hero").height,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: n.title,
      description: n.description,
      images: [newsImage(n.imagePrefix + "-hero").src],
    },
  };
}
export default async function NewsArticle({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const n = news.find((n) => n.slug === slug);
  if (!n) notFound();
  const hero = newsImage(n.imagePrefix + "-hero");
  const figure = (suffix: string, caption: string) => {
    const im = newsImage(n.imagePrefix + "-" + suffix);
    return (
      <figure className="news-figure">
        <img
          {...im}
          alt={caption}
          loading={suffix === "hero" ? "eager" : "lazy"}
        />
        <figcaption>
          {caption} <span>AI-generated conceptual illustration.</span>
        </figcaption>
      </figure>
    );
  };
  return (
    <article className="page news-story">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "News", path: "/news" },
          { name: n.title, path: newsURL(slug) },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "NewsArticle",
          headline: n.title,
          description: n.description,
          datePublished: n.publishedAt,
          dateModified: n.modifiedAt,
          image: ["hero", "detail", "infographic"].map(
            (s) =>
              "https://gopherforge.app" +
              newsImage(n.imagePrefix + "-" + s).src,
          ),
          author: {
            "@type": "Organization",
            name: "GopherForge editorial",
            url: "https://gopherforge.app/news",
          },
          publisher: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          mainEntityOfPage: "https://gopherforge.app" + newsURL(slug),
          wordCount: n.wordCount,
          inLanguage: "en",
          isAccessibleForFree: true,
          articleSection: n.category,
          keywords: n.keywords.join(", "),
          citation: n.sources.map((s) => s.url),
        }}
      />
      <Link className="back" href="/news">
        ← News & analysis
      </Link>
      <header className="news-story-header">
        <p className="eyebrow">
          {n.category} · {Math.ceil(n.wordCount / 200)} MIN READ
        </p>
        <h1>{n.title}</h1>
        <p className="article-lede">{n.description}</p>
        <p className="article-byline">
          GopherForge editorial · Published{" "}
          <time dateTime={n.publishedAt}>{dateLabel(n.publishedAt)}</time>
        </p>
        <p className="news-event">
          Event: <time dateTime={n.eventDate}>{dateLabel(n.eventDate)}</time> ·
          Reporting and practical analysis. Sources listed below.
        </p>
      </header>
      {figure("hero", `Conceptual illustration for ${n.title}`)}
      <div className="news-reading-layout">
        <aside className="news-toc">
          <p className="eyebrow">IN THIS ARTICLE</p>
          <nav aria-label="Article contents">
            {n.sections.map((s) => (
              <a href={"#" + s.id} key={s.id}>
                {s.title}
              </a>
            ))}
            <a href="#sources">Primary sources</a>
          </nav>
        </aside>
        <div className="news-reading">
          {n.sections.map((s, i) => (
            <section className="reading-section" id={s.id} key={s.id}>
              <h2>{s.title}</h2>
              <Prose>{s.body}</Prose>
              {i === 2
                ? figure("infographic", imageCaption[n.imagePrefix])
                : null}
              {i === 5
                ? figure(
                    "detail",
                    `A closer look at the workflow: ${n.sections[5].title.toLowerCase()}`,
                  )
                : null}
            </section>
          ))}
          <section id="sources" className="references">
            <h2>Primary sources & editorial method</h2>
            <p>
              We checked these primary references on{" "}
              {dateLabel(n.sourceCheckedAt)}. Release facts are attributed;
              recommended workflows and examples are GopherForge analysis.
              Illustrations are conceptual, not vendor screenshots or
              benchmarks.
            </p>
            <ul>
              {n.sources.map((s) => (
                <li key={s.url}>
                  <a href={s.url}>{s.title}</a>
                </li>
              ))}
            </ul>
          </section>
          <aside className="related">
            <p className="eyebrow">KEEP EXPLORING</p>
            <h2>Connect the ideas.</h2>
            {n.related.map((slug) => {
              const r = news.find((x) => x.slug === slug)!;
              return (
                <Link key={slug} href={newsURL(slug)}>
                  {r.title}
                  <span>→</span>
                </Link>
              );
            })}
            <Link href="/learn">Learn Go: the course map →</Link>
            <Link href="/interview">Go interview preparation →</Link>
          </aside>
        </div>
      </div>
    </article>
  );
}
