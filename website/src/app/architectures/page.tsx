import type { Metadata } from "next";
import { lessons } from "@/lib/course";
import { ArchitectureExplorer } from "@/components/ArchitectureExplorer";
import { EditorialIllustration } from "@/components/EditorialIllustration";
export const metadata: Metadata = {
  title: "Compare Go architectures",
  description:
    "Compare monoliths, hexagonal, Clean/Onion, DDD, CQRS, event-driven systems and more for three project scenarios, with costs and tradeoffs.",
  alternates: { canonical: "/architectures" },
};
export default function ArchitectureComparison() {
  const styles = lessons
    .filter(
      (l) =>
        l.unitID === "architecture" && l.reading?.designGuide?.ratings.length,
    )
    .map((l) => ({
      id: l.id,
      title: l.title,
      objective: l.objective,
      cost: l.reading!.designGuide!.cost,
      ratings: l.reading!.designGuide!.ratings,
    }));
  return (
    <section className="page narrow">
      <header className="page-intro illustrated-intro architecture-intro">
        <div className="intro-overview">
          <div className="intro-copy">
            <p className="eyebrow">ARCHITECTURE IS A TRADEOFF</p>
            <h1>
              Choose the fit.
              <br />
              <em>Understand the cost.</em>
            </h1>
            <p>
              A CLI, a complex business application and independent services ask
              different things of their architecture. Change the scenario,
              compare the approaches, then read the lesson behind each choice.
            </p>
          </div>
          <EditorialIllustration
            id="dapr-hero"
            alt="Illustration of a Go application connected to independent services."
            loading="eager"
          />
        </div>
        <p className="availability">
          These are editorial suitability ratings, not performance benchmarks,
          popularity statistics or a universal ranking. 1: usually avoid · 3:
          useful with a specific need · 5: strong starting choice. Styles can be
          combined.
        </p>
      </header>
      <ArchitectureExplorer styles={styles} />
    </section>
  );
}
