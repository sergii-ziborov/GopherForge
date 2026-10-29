import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { readSharedProgress } from "@/lib/progress-share";
import { lessons, lessonURL } from "@/lib/course";
import { interview, interviewURL } from "@/lib/interview";
export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Shared learning progress",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};
export default async function SharedProgress({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params,
    value = await readSharedProgress(id);
  if (!value) notFound();
  const { snapshot: s } = value,
    done = new Set(s.completed);
  const completed = lessons.filter((l) => done.has(l.id)),
    remaining = lessons.filter((l) => l.kind !== "predict" && !done.has(l.id));
  return (
    <div className="page lesson-page">
      <p className="eyebrow">READ-ONLY SNAPSHOT · NO ACCOUNT</p>
      <h1>Learning progress</h1>
      <p>
        Shared {s.sharedAt.slice(0, 10)} from{" "}
        {s.source === "app" ? "the native app" : "the website"}. Expires{" "}
        {value.expiresAt.slice(0, 10)}. This is learner-provided data, not
        independent certification. Opening it does not import or modify your
        progress.
      </p>
      <p>
        {completed.length} course items marked complete ·{" "}
        {s.compilerVerified.length} compiler marks reported by the app ·{" "}
        {Object.keys(s.assessments).length} interview self-assessments.
      </p>
      <p>
        <a href={`/progress/${id}/json`}>
          Machine-readable JSON for Grok, Claude, Codex or another assistant
        </a>
      </p>
      <section>
        <h2>Saved places</h2>
        {s.lastLessonID && (
          <p>
            <Link href={lessonURL(s.lastLessonID)}>
              Continue course: {s.lastLessonID}
            </Link>
          </p>
        )}
        {s.lastInterviewID && (
          <p>
            <Link href={interviewURL(s.lastInterviewID)}>
              Continue interview: {s.lastInterviewID}
            </Link>
          </p>
        )}
      </section>
      <section>
        <h2>Completed lessons</h2>
        <ul>
          {completed.map((l) => (
            <li key={l.id}>
              <Link href={lessonURL(l.id)}>{l.title}</Link> <code>{l.id}</code>
              {s.compilerVerified.includes(l.id)
                ? " · compiler mark reported"
                : " · self-reported"}
            </li>
          ))}
        </ul>
      </section>
      <section>
        <h2>Interview preparation</h2>
        <ul>
          {interview.questions
            .filter((q) => s.assessments[q.id])
            .map((q) => (
              <li key={q.id}>
                <Link href={interviewURL(q.id)}>{q.title}</Link> ·{" "}
                {s.assessments[q.id]}
              </li>
            ))}
        </ul>
      </section>
      <section>
        <h2>Possible next lessons</h2>
        <p>
          Suggestions by course order; a mark is not a complete measure of
          knowledge.
        </p>
        <ul>
          {remaining.slice(0, 12).map((l) => (
            <li key={l.id}>
              <Link href={lessonURL(l.id)}>{l.title}</Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
