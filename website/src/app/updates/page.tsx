import type { Metadata } from "next";
import Link from "next/link";
export const metadata: Metadata = {
  title: "Version history",
  description:
    "GopherForge 1.1.2 is available on the App Store. Explore the expanded web course and upcoming native architecture and clean-code lessons.",
  alternates: { canonical: "/updates" },
};
export default function Updates() {
  return (
    <article className="page article">
      <p className="eyebrow">BUILT ONE USEFUL CHANGE AT A TIME</p>
      <h1>
        What’s new.
        <br />
        <em>What’s next.</em>
      </h1>
      <section className="release" id="coming-next">
        <span className="release-badge">AVAILABLE ON THE APP STORE</span>
        <h2 id="v112">
          GopherForge 1.1.2 <small>build 36</small>
        </h2>
        <p>
          The approved version has released automatically. The course has 92
          teaching lessons across 15 units, alongside 22 prediction challenges.
        </p>
        <ul>
          <li>
            25 practical Around Go lessons: command line (11), containers (6)
            and Kubernetes (8).
          </li>
          <li>
            Actual commands, Bash and YAML highlighting, worked examples and
            pitfalls.
          </li>
          <li>
            Explicit Finish review action, smaller learned-pair boards and
            multi-round sessions.
          </li>
          <li>
            Conventional iPhone landscape controls stay fixed when the keyboard
            opens.
          </li>
        </ul>
      </section>
      <section className="release" id="next-release">
        <span className="release-badge muted">
          WEB LIBRARY AVAILABLE · APP REVIEW SUBMITTED
        </span>
        <h2>
          GopherForge 1.1.3 <small>build 37</small>
        </h2>
        <p>
          The web library now includes the expanded course: 145 teaching lessons
          in 20 units, including 98 readings, plus 22 prediction challenges. The
          native update is available to existing Internal QA testers in
          TestFlight. Build 37 is submitted to App Review with automatic release
          after approval; the public App Store version remains 1.1.2.
        </p>
        <ul>
          <li>
            19 architecture lessons, now expanded with package layout,
            transactions, failure recovery, testing and migration decisions.
          </li>
          <li>
            Eight deeper clean-code lessons on naming, interfaces, errors,
            ownership, configuration, testing, refactoring and SOLID in Go.
          </li>
          <li>
            All 23 classic design patterns and six concurrent Go patterns.
          </li>
          <li>
            53 complete worked programs and 56 design diagrams; architecture
            comparison across three scenarios with editorial fit ratings.
          </li>
        </ul>
        <figure className="native-preview">
          <a href="/images/architecture-comparison.png">
            <img
              src="/images/architecture-comparison.png"
              width="2064"
              height="2752"
              loading="lazy"
              alt="Native iPad development build comparing Go architecture approaches for a small tool or CLI"
            />
          </a>
          <figcaption>
            Native 1.1.3 preview. The web course is available now.
          </figcaption>
        </figure>
        <Link className="button" href="/learn">
          Explore the expanded course →
        </Link>
      </section>
      <section className="release">
        <span className="eyebrow">RELEASED 18 OCTOBER 2026</span>
        <h2 id="v111">GopherForge 1.1.1</h2>
        <p>
          Dependency preparation uses versions declared in go.mod, with clearer
          download errors and retry handling. Settings can clear downloaded
          package storage while keeping user code. Workspace layout and review
          practice improved.
        </p>
      </section>
      <section className="release">
        <span className="eyebrow">RELEASED 13 OCTOBER 2026</span>
        <h2 id="v11">GopherForge 1.1</h2>
        <p>
          Adaptive Duo layouts, collapsible Files navigation, keyboard helper
          visibility and Terminal-to-Code spacing fixes. All 47 original
          teaching lessons and 22 prediction challenges gained authored visual
          guides. Embedded code scrolls with the lesson; expanded code scrolls
          independently.
        </p>
      </section>
      <section className="release">
        <h2 id="v101">GopherForge 1.0.1</h2>
        <p>
          The App Store preview opens with Go code, and Settings includes app
          rating.
        </p>
      </section>
      <section className="release">
        <span className="eyebrow">RELEASED 6 OCTOBER 2026</span>
        <h2 id="v10">GopherForge 1.0</h2>
        <p>
          The original native Go workspace for iPhone and iPad: local toolchain,
          lessons, tests and Concurrency Lab.
        </p>
      </section>
    </article>
  );
}
