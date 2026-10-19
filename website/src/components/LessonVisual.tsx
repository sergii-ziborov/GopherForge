import type { Lesson } from "@/lib/course";
import { Code } from "./Code";
import { Prose } from "./Prose";
export function LessonVisual({
  guide,
}: {
  guide: NonNullable<Lesson["guide"]>;
}) {
  return (
    <section className="lesson-visual" id="visual">
      <p className="eyebrow">SEE THE IDEA</p>
      <h2>{guide.title}</h2>
      <ol className={`visual-nodes ${guide.mode}`}>
        {guide.nodes.map((node, index) => (
          <li key={node.label}>
            <span className="visual-step">
              {String(index + 1).padStart(2, "0")}
            </span>
            <h3>{node.label}</h3>
            <Code code={node.code} actions={false} />
            <div className="visual-detail">
              <Prose>{node.detail}</Prose>
            </div>
          </li>
        ))}
      </ol>
      <div className="visual-caption">
        <Prose>{guide.caption}</Prose>
      </div>
      <div className="tradeoffs">
        <div>
          <h3>In practice</h3>
          <Prose>{guide.practical}</Prose>
        </div>
        <div>
          <h3>Watch out</h3>
          <Prose>{guide.watchOut}</Prose>
        </div>
      </div>
      <a className="text-link" href={guide.reference}>
        Official reference ↗
      </a>
    </section>
  );
}
