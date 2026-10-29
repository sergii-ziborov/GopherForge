import { lessons } from "@/lib/course";
import { ProgressTransfer } from "@/components/ProgressTransfer";
import { curriculumUpdatedOn } from "@/lib/curriculum-revision";
import type { Metadata } from "next";
import { interview } from "@/lib/interview";
import { InterviewIndex } from "@/components/InterviewIndex";
import { EditorialIllustration } from "@/components/EditorialIllustration";
export const metadata: Metadata = {
  title: "Go interview preparation — junior to expert",
  description:
    "132 worked Go interview guides: algorithms, concurrency, system design, Gin, security, blockchain, MongoDB, Redis, Kubernetes and coding agents. Free without registration.",
  alternates: { canonical: "/interview" },
};
export default function InterviewPage() {
  return (
    <section className="page learn-map-page">
      <header className="page-intro course-map-intro illustrated-intro">
        <div className="intro-overview">
          <div className="intro-copy">
            <p className="eyebrow">THE NEXT LEVEL · PREPARE TO EXPLAIN</p>
            <h1>
              Your Go <em>interview map.</em>
            </h1>
            <p>
              Choose a direction, open a topic, and work through the guides —
              from your first Go interview to systems and failure analysis.
            </p>
          </div>
          <EditorialIllustration
            id="survey-detail"
            alt="Gopher turning tangled notes into clear explanations and checked examples."
            loading="eager"
          />
        </div>
        <div className="inline-stats">
          <span>
            <strong>{interview.questions.length}</strong> worked guides
          </span>
          <span>
            <strong>{interview.topics.length}</strong> topics
          </span>
          <span>
            <strong>{interview.demonstrations.length}</strong> interactive
            algorithm labs
          </span>
        </div>
        <p>
          Explain the question, compare a strong answer, then try the worked
          exercise. Junior through Staff / expert. No finite bank covers every
          possible interview.
        </p>
        <p className="availability">
          Your study marks and last opened section are saved on this browser.
          Web and app progress are independent; clearing browser data removes
          local progress.
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
      <ProgressTransfer
        lessons={lessons.map((l) => l.id)}
        interview={interview.questions.map((q) => q.id)}
        revision={curriculumUpdatedOn}
      />
    </section>
  );
}
