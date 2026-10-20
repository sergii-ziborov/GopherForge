import type { Metadata } from "next";
import { interview } from "@/lib/interview";
import { InterviewIndex } from "@/components/InterviewIndex";
export const metadata: Metadata = {
  title: "Go interview preparation — junior to expert",
  description:
    "Worked Go interview questions, interactive algorithm traces, concurrency, runtime, MongoDB, Redis, Docker, Kubernetes and coding-agent workflows. Free without registration.",
  alternates: { canonical: "/interview" },
};
export default function InterviewPage() {
  return (
    <div className="page section-space">
      <header className="interview-hero">
        <p className="eyebrow">THE NEXT LEVEL · PREPARE TO EXPLAIN</p>
        <h1>
          Know the answer.
          <br />
          <em>Show the reasoning.</em>
        </h1>
        <p className="lesson-objective">
          {interview.questions.length} worked guides. {interview.topics.length}{" "}
          connected topics. From your first Go interview to systems and failure
          analysis.
        </p>
        <p>
          Each guide includes a strong answer, a tempting wrong answer, a worked
          exercise and a follow-up. Eight algorithm labs let you step through 24
          input scenarios. The map is a route through the subject, with every
          level open.
        </p>
        <ol className="level-route">
          {interview.levels.map((l) => (
            <li key={l}>{l}</li>
          ))}
        </ol>
        <p className="small-note">
          No finite bank covers every possible interview. Use these guides to
          practice deriving an answer when the constraints change. Native 1.1.4
          adds the same separate Interview area; web and app progress are
          independent.
        </p>
      </header>
      <InterviewIndex
        questions={interview.questions.map(
          ({ id, title, prompt, topic, level }) => ({
            id,
            title,
            prompt,
            topic,
            level,
          }),
        )}
        topics={interview.topics}
        levels={interview.levels}
      />
    </div>
  );
}
