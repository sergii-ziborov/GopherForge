import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import guide from "@/content/app-guide.json";
import { Prose } from "@/components/Prose";
import { StructuredData, Breadcrumbs } from "@/components/StructuredData";
import { appStore } from "@/lib/course";
import { releases } from "@/lib/releases";
export const metadata: Metadata = {
  title: "GopherForge Guide: Go Compiler for iPhone & iPad",
  description:
    "A practical GopherForge guide: create Go projects, compile offline, run tests, manage packages, save learning progress and prepare for Go interviews. Includes sandbox limits.",
  alternates: { canonical: "/guide" },
  openGraph: {
    title: "The complete GopherForge app guide",
    description:
      "From your first Go project to tests, Continue, interview practice and package compatibility.",
    type: "article",
    url: "/guide",
    modifiedTime: guide.updated,
    images: [
      {
        url: "/images/app-icon.png",
        width: 1024,
        height: 1024,
        alt: "GopherForge turquoise gopher with copper goggles on a dark teal background",
      },
    ],
  },
};
export default function AppGuide() {
  return (
    <div className="guide-page page">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "App guide", path: "/guide" },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "TechArticle",
          headline: "The complete GopherForge app guide",
          description: metadata.description,
          dateModified: guide.updated,
          inLanguage: "en",
          url: "https://gopherforge.app/guide",
          image: "https://gopherforge.app/images/app-icon.png",
          author: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          about: {
            "@type": "SoftwareApplication",
            name: "GopherForge",
            operatingSystem: "iOS, iPadOS",
            applicationCategory: "DeveloperApplication",
          },
        }}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "FAQPage",
          mainEntity: guide.faq.map((f) => ({
            "@type": "Question",
            name: f.question,
            acceptedAnswer: { "@type": "Answer", text: f.answer },
          })),
        }}
      />
      <header className="guide-hero">
        <Image
          src="/images/app-icon.png"
          width={160}
          height={160}
          alt="GopherForge gopher with copper goggles"
          priority
        />
        <div>
          <p className="eyebrow">
            THE APP, EXPLAINED · UPDATED 27 OCTOBER 2026
          </p>
          <h1>
            Your Go workbench.
            <br />
            <em>Know your tools.</em>
          </h1>
          <p className="lesson-objective">
            A practical guide to building, learning and preparing for interviews
            with GopherForge on iPhone, iPad and the web.
          </p>
          <p className="small-note">
            App Store: {releases.public.version}. Expanded library:{" "}
            {releases.next.version} · {releases.next.status}.{" "}
            <Link href="/updates">Release details →</Link>
          </p>
        </div>
      </header>
      <div className="guide-body">
        <aside className="guide-toc">
          <p className="eyebrow">IN THIS GUIDE</p>
          <nav aria-label="App guide contents">
            {guide.sections.map((s, i) => (
              <a key={s.id} href={`#${s.id}`}>
                <span>{String(i + 1).padStart(2, "0")}</span>
                {s.title}
              </a>
            ))}
            <a href="#questions">Common questions</a>
          </nav>
        </aside>
        <article className="guide-content">
          {guide.sections.map((s, i) => (
            <section className="reading-section" id={s.id} key={s.id}>
              <p className="eyebrow">
                {String(i + 1).padStart(2, "0")} / WORKBENCH GUIDE
              </p>
              <h2>{s.title}</h2>
              <Prose>{s.body}</Prose>
              {s.id === "first-project" ? (
                <figure className="guide-screen">
                  <img
                    src="/images/workbench.png"
                    width="1320"
                    height="2868"
                    loading="lazy"
                    alt="GopherForge native editor with a real Go worker-pool program"
                  />
                  <figcaption>
                    Real native editor. Start with one small, testable change.
                  </figcaption>
                </figure>
              ) : null}
            </section>
          ))}
          <section className="reading-section" id="questions">
            <h2>Common questions</h2>
            {guide.faq.map((f) => (
              <details key={f.question}>
                <summary>{f.question}</summary>
                <p>{f.answer}</p>
              </details>
            ))}
          </section>
          <section className="guide-next">
            <h2>Put it into practice.</h2>
            <p>One project, one test, one concept you can explain.</p>
            <div className="hero-actions">
              <a href={appStore} className="button">
                Get GopherForge ↗
              </a>
              <Link href="/learn" className="button secondary">
                Explore the free course →
              </Link>
            </div>
          </section>
        </article>
      </div>
    </div>
  );
}
