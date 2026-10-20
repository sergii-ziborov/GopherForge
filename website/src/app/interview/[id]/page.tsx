import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { interview, interviewURL } from "@/lib/interview";
import { Code } from "@/components/Code";
import { Prose } from "@/components/Prose";
import { AlgorithmTrace } from "@/components/AlgorithmTrace";
import { InterviewAssessment } from "@/components/InterviewAssessment";
export function generateStaticParams() {
  return interview.questions.map((q) => ({ id: q.id }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const q = interview.questions.find((q) => q.id === id);
  return {
    title: q?.title ?? "Guide not found",
    description: q?.prompt,
    alternates: { canonical: interviewURL(id) },
  };
}
export default async function InterviewDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const i = interview.questions.findIndex((q) => q.id === id);
  if (i < 0) notFound();
  const q = interview.questions[i];
  const topic = interview.topics.find((t) => t.id === q.topic);
  const demo = interview.demonstrations.find((d) => d.id === id);
  const next = interview.questions[i + 1];
  return (
    <div className="lesson-layout">
      <aside className="lesson-toc">
        <Link href="/interview">← Interview map</Link>
        <p className="eyebrow">{topic?.title}</p>
        <nav aria-label="Preparation sections">
          <a href="#question">Question</a>
          {demo && <a href="#demonstration">Interactive trace</a>}
          <a href="#answer">Strong answer</a>
          <a href="#exercise">Worked exercise</a>
          <a href="#follow-up">Follow-up</a>
          <a href="#sources">References</a>
        </nav>
      </aside>
      <article className="lesson-article">
        <header id="question">
          <p className="eyebrow">
            {interview.levels[q.level - 1]} · {topic?.title}
          </p>
          <h1>{q.title}</h1>
          <p className="lesson-objective">{q.prompt}</p>
          <p>
            Try explaining this aloud before opening the answer. State your
            assumptions and trace a boundary case.
          </p>
        </header>
        {demo && (
          <div id="demonstration">
            <AlgorithmTrace demonstration={demo} />
          </div>
        )}
        {q.code && (
          <section>
            <p className="card-meta">
              EXAMPLE · FRAGMENT UNLESS A COMPLETE PROGRAM IS SHOWN
            </p>
            <Code
              code={q.code}
              language={
                q.topic === "modules"
                  ? "bash"
                  : q.topic === "ai"
                    ? "text"
                    : "go"
              }
            />
          </section>
        )}
        <section id="answer">
          <details className="interview-answer">
            <summary>Reveal a strong answer</summary>
            <ol>
              {q.answerPoints.map((p, j) => (
                <li key={j}>
                  <Prose>{p}</Prose>
                </li>
              ))}
            </ol>
            <div className="interview-trap">
              <h2>Common trap</h2>
              <Prose>{q.trap}</Prose>
            </div>
            {q.complexity && (
              <>
                <h2>Complexity & use</h2>
                <Prose>{q.complexity}</Prose>
              </>
            )}
          </details>
        </section>
        <section id="exercise">
          <h2>Try it</h2>
          <Prose>{q.exercise}</Prose>
          <details className="interview-answer">
            <summary>Worked solution</summary>
            <Prose>{q.solution}</Prose>
          </details>
        </section>
        <section id="follow-up">
          <h2>Change the constraint</h2>
          <Prose>{q.followUp}</Prose>
        </section>
        <InterviewAssessment id={q.id} />
        <section id="sources">
          <h2>Primary references</h2>
          <p className="small-note">
            Checked {interview.reviewedOn}. Use documentation for your pinned
            runtime, driver and tool version.
          </p>
          <ul>
            {q.references.map((r) => (
              <li key={r}>
                <a href={r} rel="noreferrer">
                  {new URL(r).hostname}
                  {new URL(r).pathname}
                </a>
              </li>
            ))}
          </ul>
        </section>
        <nav className="lesson-next" aria-label="Next preparation guide">
          <Link href="/interview">← Back to the map</Link>
          {next && (
            <Link href={interviewURL(next.id)}>Next: {next.title} →</Link>
          )}
        </nav>
      </article>
    </div>
  );
}
