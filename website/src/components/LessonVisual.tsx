import type { Lesson } from "@/lib/course";
import { Code } from "./Code";
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
            <p>{node.detail}</p>
          </li>
        ))}
      </ol>
      <p className="visual-caption">{guide.caption}</p>
      <div className="tradeoffs">
        <div>
          <h3>In practice</h3>
          <p>{guide.practical}</p>
        </div>
        <div>
          <h3>Watch out</h3>
          <p>{guide.watchOut}</p>
        </div>
      </div>
      <a className="text-link" href={guide.reference}>
        Official reference ↗
      </a>
    </section>
  );
}
