import { StudyContinue } from "@/components/StudyContinue";
import { interview } from "@/lib/interview";
import Link from "next/link";
import { appStore, github, lessons, units, readings } from "@/lib/course";
import { posts } from "@/lib/posts";
import { Code } from "@/components/Code";
const heroCode = `package main\n\nimport "fmt"\n\nfunc main() {\n    ideas := []string{"learn", "build", "understand"}\n    for _, idea := range ideas {\n        fmt.Println("Go", idea)\n    }\n}`;
export default function Home() {
  return (
    <>
      <StudyContinue
        course={lessons.map(({ id, title }) => ({ id, title }))}
        interview={interview.questions.map(({ id, title }) => ({ id, title }))}
      />
      <section className="hero page">
        <div className="hero-copy">
          <p className="eyebrow">
            <span className="status-dot" />
            GO BEYOND THE TUTORIAL
          </p>
          <h1>
            Learn it.
            <br />
            Build it.
            <br />
            <em>Make it Go.</em>
          </h1>
          <p>
            A practical learning library and a native Go workbench. Understand
            the language, make better design decisions, and turn your next idea
            into working code.
          </p>
          <div className="hero-actions">
            <Link href="/learn" className="button">
              Explore the free course <span>→</span>
            </Link>
            <a href={appStore} className="button secondary">
              Get the iOS app ↗
            </a>
          </div>
          <p className="small-note">
            Free web lessons. iOS app: $6.99 USD, one-time U.S. purchase.
            Regional prices vary.
          </p>
        </div>
        <div className="hero-workbench">
          <div className="window-bar">
            <span>
              <i />
              <i />
              <i />
            </span>
            <span>main.go</span>
            <span>Go 1.27.1</span>
          </div>
          <Code code={heroCode} />
          <div className="terminal-output">
            <span>OUTPUT</span>
            <pre>
              Go learn{"\n"}Go build{"\n"}Go understand
            </pre>
            <span className="terminal-status">● Example output</span>
          </div>
          <div className="hero-caption">
            <span>A little curiosity. A real toolchain.</span>
            <span>_</span>
          </div>
        </div>
      </section>
      <section className="stats-band">
        <div>
          <strong>{lessons.length}</strong>
          <span>lessons & challenges</span>
        </div>
        <div>
          <strong>{units.length}</strong>
          <span>focused units</span>
        </div>
        <div>
          <strong>{readings.length}</strong>
          <span>in-depth readings</span>
        </div>
        <div>
          <strong>0</strong>
          <span>accounts required to learn</span>
        </div>
      </section>
      <section className="page section-space">
        <div className="section-heading">
          <div>
            <p className="eyebrow">FOLLOW YOUR CURIOSITY</p>
            <h2>
              Start small.
              <br />
              <em>Go as deep as you like.</em>
            </h2>
          </div>
          <Link href="/learn" className="text-link">
            Browse the whole course ↗
          </Link>
        </div>
        <div className="path-grid">
          {[
            {
              n: "01",
              title: "Build your Go foundation",
              body: "Values, control flow, slices, errors and packages. Understand the rules behind the syntax.",
              unit: "core",
              label: "Start with the basics",
            },
            {
              n: "02",
              title: "Make the design deliberate",
              body: "Compare architectures, read clean Go, and apply patterns with a reason and a tradeoff.",
              unit: "architecture",
              label: "Explore architecture",
            },
            {
              n: "03",
              title: "Know the environment",
              body: "Actual Bash, Git, Docker and Kubernetes commands. Read what happens around your Go program.",
              unit: "operations",
              label: "Explore the tooling",
            },
          ].map((p) => (
            <Link
              className="path-card"
              href={`/learn?unit=${p.unit}`}
              key={p.n}
            >
              <span>{p.n} / LEARNING PATH</span>
              <h3>{p.title}</h3>
              <p>{p.body}</p>
              <strong>{p.label} →</strong>
            </Link>
          ))}
        </div>
        <div className="comparison-link">
          <div>
            <h3>Which architecture fits your project?</h3>
            <p>
              Compare 17 approaches across a CLI, a domain-rich app and
              independent services. Read the tradeoffs beside the score.
            </p>
          </div>
          <Link className="button secondary" href="/architectures">
            Compare approaches →
          </Link>
        </div>
      </section>
      <section className="page section-space interview-preview">
        <p className="eyebrow">NEXT LEVEL · INTERVIEW PREPARATION</p>
        <h2>
          From syntax to
          <br />
          <em>engineering judgment.</em>
        </h2>
        <p>
          88 worked guides across 12 topics, from junior foundations to systems
          tradeoffs. Trace eight algorithms interactively, then practice
          concurrency, MongoDB, Redis, Docker, Kubernetes and Go workflows with
          Claude Code, Codex and Cursor.
        </p>
        <Link className="button" href="/interview">
          Open interview preparation →
        </Link>
      </section>
      <section className="app-section">
        <div className="page app-grid">
          <div className="app-image">
            <img
              src="/images/workbench.png"
              alt="GopherForge native iPhone workbench showing highlighted Go source code"
              width="1320"
              height="2868"
              loading="lazy"
            />
          </div>
          <div>
            <p className="eyebrow">THE WORKBENCH IN YOUR POCKET</p>
            <h2>
              Real Go.
              <br />
              <em>Wherever you are.</em>
            </h2>
            <p>
              Write, compile, run, test, vet and format with a bundled Go 1.27.1
              toolchain. Keep your projects on iPhone or iPad, import from
              GitHub, and work locally once dependencies are present.
            </p>
            <ul className="feature-list">
              <li>
                <strong>Built for the screen you have.</strong> Native iPhone,
                iPad and adaptive Duo layouts.
              </li>
              <li>
                <strong>More than a code editor.</strong> Project files, tests,
                concurrency timelines and idiom guidance.
              </li>
              <li>
                <strong>Your code, on your device.</strong> Compilation happens
                locally in the app.
              </li>
            </ul>
            <div className="hero-actions">
              <a href={appStore} className="button">
                View on the App Store ↗
              </a>
              <Link className="text-link" href="/support#package-limits">
                Read the toolchain limits
              </Link>
            </div>
            <div className="app-price" id="pricing">
              <strong>$6.99 USD</strong>
              <span>One-time purchase · U.S. App Store</span>
              <p>
                No subscription or in-app purchases. Regional prices and taxes
                vary; the App Store shows your final local price. Web lessons
                and interview preparation are free.
              </p>
            </div>
            <p className="small-note">
              App Store version 1.1.3 is available now. The web course includes
              the latest architecture, MongoDB, Redis and production-tooling
              readings. Native availability is listed in the version history.
            </p>
          </div>
        </div>
      </section>
      <section className="page section-space">
        <div className="section-heading">
          <div>
            <p className="eyebrow">FIELD NOTES</p>
            <h2>
              Less theory on a shelf.
              <br />
              <em>More ideas you can use.</em>
            </h2>
          </div>
          <Link href="/blog" className="text-link">
            Read all field notes ↗
          </Link>
        </div>
        <div className="blog-grid">
          {posts.slice(0, 3).map((p) => (
            <Link className="blog-tile" href={`/blog/${p.slug}`} key={p.slug}>
              <p className="card-meta">
                {p.category} · {p.readingMinutes} MIN
              </p>
              <h3>{p.title}</h3>
              <p>{p.description}</p>
              <span>Read the note ↗</span>
            </Link>
          ))}
        </div>
      </section>
      <section className="closing page">
        <p className="eyebrow">ONE GOOD NEXT STEP</p>
        <h2>
          You don’t need to know it all.
          <br />
          <em>Just start with one lesson.</em>
        </h2>
        <Link className="button" href="/learn">
          Find your next idea →
        </Link>
        <a href={github} className="text-link">
          Explore the source ↗
        </a>
      </section>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            name: "GopherForge: Go Workbench",
            applicationCategory: "DeveloperApplication",
            operatingSystem: "iOS, iPadOS",
            softwareVersion: "1.1.3",
            offers: {
              "@type": "Offer",
              price: "6.99",
              priceCurrency: "USD",
              url: appStore,
            },
            url: "https://gopherforge.app",
            downloadUrl: appStore,
          }),
        }}
      />
    </>
  );
}
