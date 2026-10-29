import type { Metadata } from "next";
import Link from "next/link";
import { releases } from "@/lib/releases";
export const metadata: Metadata = {
  title: "Version history",
  description:
    "GopherForge 1.3.1 is on the App Store with 220 Go lessons and 132 interview guides. The 1.3.2 development preview adds MCP collaboration and shareable progress.",
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
      <section className="release" id="v131">
        <span className="release-badge muted">AVAILABLE ON THE APP STORE</span>
        <h2>
          GopherForge 1.3.1 <small>build 49</small>
        </h2>
        <p>
          Apple released 1.3.1 after review. The course includes 220 teaching
          lessons, 173 readings and 22 prediction challenges across 28 units,
          plus 132 interview guides. Offline React, the source debugger, direct
          web previews, source recovery and saved Continue places are included.
        </p>
        <Link className="button" href="/learn">
          Explore the course →
        </Link>
      </section>
      <section className="release" id="v132">
        <span className="release-badge muted">
          {releases.next.status.toUpperCase()} ·{" "}
          {releases.beta.status.toUpperCase()}
        </span>
        <h2>
          GopherForge {releases.curriculum.version}{" "}
          <small>build {releases.curriculum.build}</small>
        </h2>
        <p>
          The development preview adds a guest Playground for people and AI, a
          Streamable HTTP MCP server for Claude/Codex, and explicit read-only
          progress links for teachers and assistants. Run/Test is local to the
          native device whose person presses the button; other participants
          receive Output.
        </p>
        <p>
          Explore Gin middleware and request ownership, blockchain package
          choices and reorg-safe indexing, service security,
          transaction/outbox/saga design, gRPC, Kafka and production clean code.
          Architecture &amp; clean code now contains four units and 40 lessons.
          Existing progress IDs and the twelve interactive algorithm labs are
          retained.
        </p>
        <p>
          Version {releases.next.version} ({releases.next.build}) is{" "}
          {releases.next.status.toLowerCase()}. Room expiry, source revisions,
          local copies and provider boundaries are explained in the MCP guide.
        </p>
        <Link className="button" href="/learn?direction=design">
          Explore the expanded learning map →
        </Link>
      </section>
      <section className="release" id="v130">
        <span className="release-badge muted">
          EARLIER TESTFLIGHT · SUPERSEDED BY 1.3.1
        </span>
        <h2>
          GopherForge 1.3.0 <small>build 48</small>
        </h2>
        <p>
          Build a React interface offline and trace your Go program one
          statement at a time. These workbench features first appeared in the
          1.3.0 beta and are included in 1.3.1 (49), which replaces that review
          candidate. The App Store currently distributes 1.3.1.
        </p>
        <ul>
          <li>
            Build &amp; Preview directly from Output, full-screen and reload
            controls, project archive sharing, and device-only browser/address
            actions for static previews. Isolated React origins remain inside
            GopherForge.
          </li>
          <li>
            Restored lesson drafts and pre-solution source, assistance-aware
            attempts, direct Practice access, and safer Files library
            restoration. Exact GitHub commit snapshots and visible import
            omissions; strict terminal validation preserves what a command
            actually means.
          </li>
          <li>
            Documented npm install/build/preview commands, bundled esbuild WASI
            and a fixed React catalog. No Node server, Bun or registry
            downloads.
          </li>
          <li>
            Optional local Go API paths through the educational Gin-compatible
            adapter. Real handlers execute with bounded request replay; no
            sockets or cloud runtime.
          </li>
          <li>
            Tap a Go line number for a breakpoint. Run executes normally without
            breakpoints and automatically starts the source debugger when they
            exist.
          </li>
          <li>
            Continue, Into/Over/Out, Stop, an own-source call stack and
            current-frame local values. Breakpoints persist per project; saved
            source is unchanged.
          </li>
        </ul>
        <p>
          External React + Gin source was used only for interoperability
          verification and is not bundled as an app example. TestFlight access
          is private; there is no public invitation link.
        </p>
        <Link className="button" href="/guide#offline-react">
          Read the beta walkthrough →
        </Link>
      </section>
      <section className="release" id="v120">
        <span className="release-badge muted">AVAILABLE ON THE APP STORE</span>
        <h2>
          GopherForge 1.2.0 <small>build 45</small>
        </h2>
        <p>
          The expanded library has 186 teaching lessons, 139 worked readings and
          22 prediction challenges in 23 units. Existing lesson identifiers and
          local progress are preserved.
        </p>
        <ul>
          <li>
            Fifteen new readings: JSON v2 contracts and input policy;
            WaitGroup.Go, synctest and errgroup; SQL pool and transaction
            ownership; practical Go coding-agent workflows.
          </li>
          <li>
            Four new interactive labs: topological sorting, union-find, LRU
            eviction and merging intervals. Interview now contains 92 guides and
            12 labs with 36 scenarios.
          </li>
          <li>
            Corrected generic Stack.Pop reference retention, numeric Sum
            constraints and the three range-over-function signatures.
          </li>
          <li>
            A new dark teal gopher icon, refreshed learning screenshots and a
            complete app guide.
          </li>
        </ul>
        <p>
          Status checked {releases.checkedOn}. The App Store currently
          distributes {releases.public.version}. New web lessons explain native
          external tools; they do not add networking, AI services or database
          servers to the app sandbox.
        </p>
        <Link className="button" href="/guide">
          Read the complete app guide →
        </Link>
      </section>
      <section className="release" id="v116">
        <span className="release-badge muted">AVAILABLE ON THE APP STORE</span>
        <h2>
          GopherForge 1.1.6 <small>build 44</small>
        </h2>
        <p>
          Two worked readings cover borrowed bytes.Buffer and Scanner data,
          owned results, sync.Pool lifetimes, oversize retention and parallel
          tests. This release contains 171 teaching lessons, 124 readings and 22
          prediction challenges in 21 units.
        </p>
        <Link
          className="button secondary"
          href="/learn/stdlib.borrowed-buffers"
        >
          Trace buffer ownership →
        </Link>
      </section>
      <section className="release" id="v115">
        <span className="release-badge muted">AVAILABLE ON THE APP STORE</span>
        <h2>
          GopherForge 1.1.5 <small>build 43</small>
        </h2>
        <p>
          Continue returns to your last course lesson or interview guide.
          Learning progress, completion evidence and your selected study area
          persist locally across relaunches. Version 1.1.5 is available on the
          App Store. Status checked 23 October 2026.
        </p>
        <ul>
          <li>Separate saved places for Course and Interview.</li>
          <li>
            Course and Interview share the same study layout. Duplicate
            Projects, Learn and Settings root headings are removed to give
            content more room. Store learning screenshots now reflect this
            layout.
          </li>
          <li>
            Completion and compiler evidence survive practice-history pruning.
          </li>
          <li>
            Eight Go coding-agent guides cover Codex, Claude, Cursor, API
            validation, security and concurrency review.
          </li>
        </ul>
        <p>
          The website already offers Continue from the home page and course
          maps, including the last reading section. Web and app progress remain
          separate; no account is needed.
        </p>
        <Link className="button" href="/interview/ai.workflow">
          Work with Go coding agents →
        </Link>
      </section>
      <section className="release" id="v114">
        <span className="release-badge muted">
          AVAILABLE ON THE APP STORE · WEB AVAILABLE
        </span>
        <h2>
          GopherForge 1.1.4 <small>build 39</small>
        </h2>
        <p>
          The library now has 169 teaching lessons in 21 units, including 122
          readings, plus 22 prediction challenges. New material is available on
          the web and in native 1.1.4, now published on the App Store.
        </p>
        <ul>
          <li>
            A separate Interview area with 88 worked guides across 12 topics and
            four difficulty levels. Eight algorithm labs provide 24 scenarios
            and 111 computed steps, plus Go code, worked exercises and local
            self-assessment.
          </li>
          <li>
            Six MongoDB lessons: shared clients, query indexes, atomic writes,
            transaction retries, cursor ownership and pool saturation.
          </li>
          <li>
            Six Redis lessons: bounded clients, cache-aside, pipelines, leases,
            consumer groups, memory pressure and ambiguous write outcomes.
          </li>
          <li>
            Twelve additional module/tooling readings: version graphs, private
            modules, workspaces, vendor and embed, parallel tests, benchmarks,
            profiles, build capacity, pinned tools, fuzzing and startup
            ownership.
          </li>
          <li>
            Native code and lessons gain scrollable end space and a transparent
            lower edge around the floating navigation controls.
          </li>
        </ul>
        <Link className="button secondary" href="/interview">
          Prepare for an interview →
        </Link>
        <Link className="button" href="/learn?direction=tooling">
          Explore Around Go →
        </Link>
      </section>
      <section className="release" id="next-release">
        <span className="release-badge muted">AVAILABLE ON THE APP STORE</span>
        <h2>
          GopherForge 1.1.3 <small>build 37</small>
        </h2>
        <p>
          This native update includes the expanded course: 145 teaching lessons
          in 20 units, including 98 readings, plus 22 prediction challenges. The
          update has passed App Review and released automatically. Version 1.1.3
          is an earlier public release; later updates are listed above.
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
      <section className="release" id="coming-next">
        <span className="release-badge">PREVIOUS RELEASE</span>
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
