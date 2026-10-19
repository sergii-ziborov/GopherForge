import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { lessons, lessonByID, lessonURL, minutes } from "@/lib/course";
import { Code } from "@/components/Code";
import { Prose } from "@/components/Prose";
import { Quiz } from "@/components/Quiz";
import { LessonProgress } from "@/components/LessonProgress";
import { LessonVisual } from "@/components/LessonVisual";
export function generateStaticParams() {
  return lessons.map((l) => ({ id: l.id }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const l = lessonByID.get(id);
  return {
    title: l?.title ?? "Lesson not found",
    description: l?.objective,
    alternates: { canonical: lessonURL(id) },
  };
}
export default async function LessonPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const l = lessonByID.get(id);
  if (!l) notFound();
  const index = lessons.findIndex((x) => x.id === id);
  const prev = lessons[index - 1],
    next = lessons[index + 1];
  const guide = l.reading?.designGuide;
  return (
    <div className="lesson-layout">
      <aside className="lesson-toc">
        <Link href={`/learn?unit=${l.unitID}`} className="back">
          ← {l.unitTitle}
        </Link>
        <p className="eyebrow">IN THIS LESSON</p>
        <nav aria-label="Lesson sections">
          <a href="#overview">Overview</a>
          {l.guide ? <a href="#visual">See the idea</a> : null}
          {guide ? <a href="#design">Design & tradeoffs</a> : null}
          {l.reading?.sections.map((s, i) => (
            <a key={i} href={`#section-${i}`}>
              {s.title}
            </a>
          ))}
          {l.reading?.quiz ? <a href="#practice">Check understanding</a> : null}
          <a href="#finish">Finish & continue</a>
        </nav>
      </aside>
      <article className="lesson-article">
        <header id="overview">
          <p className="eyebrow">
            {l.unitTitle} <span>· {minutes(l)} MIN READ</span>
          </p>
          <h1>{l.title}</h1>
          <p className="lesson-objective">{l.objective}</p>
          <Prose>{l.explanation}</Prose>
        </header>
        {l.guide ? <LessonVisual guide={l.guide} /> : null}
        {guide ? (
          <section className="design-panel" id="design">
            <p className="eyebrow">{guide.family} · A MAP OF THE IDEA</p>
            <ol className="flow">
              {guide.flow.map((f) => (
                <li key={f}>{f}</li>
              ))}
            </ol>
            <div className="tradeoffs">
              <div>
                <h2>Useful when</h2>
                <ul>
                  {guide.strengths.map((s) => (
                    <li key={s}>{s}</li>
                  ))}
                </ul>
              </div>
              <div>
                <h2>Watch out</h2>
                <ul>
                  {guide.cautions.map((s) => (
                    <li key={s}>{s}</li>
                  ))}
                </ul>
              </div>
            </div>
            <p>
              <strong>Implementation & operation cost:</strong> {guide.cost}
            </p>
            {guide.ratings.length ? (
              <>
                <h2>Fit depends on the task</h2>
                <div className="ratings">
                  {guide.ratings.map((r) => (
                    <div key={r.scenario}>
                      <span>{r.scenario}</span>
                      <strong>{r.score}/5</strong>
                      <meter
                        min="1"
                        max="5"
                        value={r.score}
                        aria-label={`${r.scenario}: ${r.score} out of 5`}
                      />
                    </div>
                  ))}
                </div>
                <p className="small-note">
                  Editorial suitability, not benchmarks or a universal ranking.
                  Styles describe different axes and can be combined.
                </p>
              </>
            ) : null}
          </section>
        ) : null}
        {l.reading ? (
          l.reading.sections.map((s, i) => (
            <section className="reading-section" id={`section-${i}`} key={i}>
              <span className="section-number">
                {String(i + 1).padStart(2, "0")}
              </span>
              <h2>{s.title}</h2>
              <Prose>{s.body}</Prose>
              {s.code ? <Code code={s.code} language={s.language} /> : null}
              {s.walkthrough ? (
                <div className="walkthrough">
                  <strong>Read the code</strong>
                  <Prose>{s.walkthrough}</Prose>
                </div>
              ) : null}
            </section>
          ))
        ) : (
          <section className="reading-section">
            <h2>
              {l.kind === "predict"
                ? "Read and predict"
                : "Work through the exercise"}
            </h2>
            {l.source ? <Code code={l.source} /> : null}
            {l.question ? <Prose>{l.question}</Prose> : null}
            <div className="walkthrough">
              <strong>Try it yourself</strong>
              <p>
                Trace each value and write down your reasoning. Copy the source
                into GopherForge or your local Go environment to compile and
                check it. This web page does not execute your code or send it to
                a compiler service.
              </p>
            </div>
          </section>
        )}
        {l.reading?.takeaway ? (
          <section className="takeaway">
            <p className="eyebrow">TAKE THIS WITH YOU</p>
            <Prose>{l.reading.takeaway}</Prose>
          </section>
        ) : null}
        {l.reading?.quiz ? (
          <div id="practice">
            <Quiz quiz={l.reading.quiz} id={l.id} />
          </div>
        ) : null}
        {l.reading?.references.length ? (
          <section className="references">
            <h2>Go to the source</h2>
            <ul>
              {l.reading.references.map((url) => (
                <li key={url}>
                  <a href={url} rel="noopener noreferrer">
                    {new URL(url).hostname.replace("www.", "")}
                    {new URL(url).pathname}
                  </a>
                </li>
              ))}
            </ul>
          </section>
        ) : null}
        <section id="finish">
          <LessonProgress id={l.id} />
        </section>
        <nav className="lesson-pagination" aria-label="Adjacent lessons">
          {prev ? (
            <Link href={lessonURL(prev.id)}>
              <small>← Previous</small>
              {prev.title}
            </Link>
          ) : (
            <span />
          )}
          {next ? (
            <Link href={lessonURL(next.id)}>
              <small>Next →</small>
              {next.title}
            </Link>
          ) : (
            <Link href="/learn">Back to the course →</Link>
          )}
        </nav>
      </article>
    </div>
  );
}
