import { releases } from "@/lib/releases";
import Link from "next/link";
import type { Metadata } from "next";
import { github, appStore } from "@/lib/course";
export const metadata: Metadata = {
  title: "Support & package compatibility",
  description:
    "Contact GopherForge support. Understand WASI, module downloads, the 4,000-file ZIP budget and what the on-device Go toolchain supports.",
  alternates: { canonical: "/support" },
};
export default function Support() {
  return (
    <article className="page article">
      <p className="eyebrow">HELP WHEN YOU NEED IT</p>
      <h1>
        Support,
        <br />
        <em>without the guesswork.</em>
      </h1>
      <section className="contact-card">
        <h2>Talk to the developer</h2>
        <p>
          Email{" "}
          <a href="mailto:sergii.ziborov@gmail.com">sergii.ziborov@gmail.com</a>
          , or <a href={`${github}/issues`}>report an issue on GitHub</a>. Email
          does not require a GitHub account.
        </p>
        <p>
          Include the app version and build from Settings → About, your device
          and system version, the steps to reproduce, and the exact error from
          Problems or Output. Remove credentials and private code before sharing
          a public report.
        </p>
      </section>
      <section className="reading-section">
        <h2>What can I build?</h2>
        <p>
          GopherForge bundles Go 1.27.1 and compiles locally. It supports
          pure-Go programs, multi-file projects, tests, vet, formatting and
          compatible vendored dependencies. Package and GitHub downloads need a
          connection; later builds use source already present.
        </p>
        <p>
          The WASI sandbox excludes cgo, native assembly and guest-program
          networking. Vendoring does not preserve arbitrary non-Go{" "}
          <code>go:embed</code> assets. Local HTML/JavaScript previews can
          contact remote services referenced by that content. The app console
          runs project operations; it is not Bash, SSH or a Kubernetes shell.
        </p>
        <p>
          Automatic dependency preparation uses versions declared in{" "}
          <code>go.mod</code>, not a full module-version solver.{" "}
          <code>go.work</code> semantics are not implemented. An infinite loop
          has no guaranteed Stop; close and reopen the app if it becomes
          unresponsive.
        </p>
      </section>
      <section className="reading-section" id="beta-tools">
        <h2>React/npm and source debugger beta</h2>
        <p>
          The 1.3.0 TestFlight beta adds a fixed offline browser package catalog
          and a documented npm command subset. Unknown packages, Node APIs,
          arbitrary scripts, Vite plugins and Bun are unsupported. The isolated
          frontend preview blocks external network requests; this differs from
          legacy local HTML previews.
        </p>
        <p>
          Optional Gin-compatible request replay supports small deterministic
          teaching APIs. It does not run a general server or database. With
          breakpoints, Run starts the beta source debugger; without them it runs
          normally. Stop needs an instrumented project checkpoint and cannot
          guarantee interruption inside uninstrumented dependency code.
        </p>
        <Link href="/guide#offline-react" className="text-link">
          Commands, examples and detailed limits →
        </Link>
      </section>
      <section className="reading-section" id="package-limits">
        <p className="eyebrow">BEFORE YOU IMPORT</p>
        <h2>Module download limits</h2>
        <p>
          These are resource budgets enforced by GopherForge, not Go language
          limits. Each budget applies independently.
        </p>
        <dl className="budget-cards">
          <div>
            <dt>4,000 files per module ZIP</dt>
            <dd>
              All non-directory entries count before decompression, checksum
              comparison and platform/source filtering. Tests, documentation and
              other-platform sources count even if later discarded. This is not
              the final retained file count or a total project limit.
            </dd>
          </div>
          <div>
            <dt>96 MiB compressed</dt>
            <dd>
              Maximum bytes downloaded for one module ZIP: 100,663,296 bytes.
            </dd>
          </div>
          <div>
            <dt>512 MiB uncompressed</dt>
            <dd>Maximum uncompressed module size: 536,870,912 bytes.</dd>
          </div>
          <div>
            <dt>80 modules per preparation pass</dt>
            <dd>
              Dependencies are prepared from requirements already declared in
              go.mod.
            </dd>
          </div>
        </dl>
        <h3>The modernc.org/libc example</h3>
        <p>
          <code>modernc.org/libc@v1.75.3</code> contains 4,168 archive files and
          exceeds the 4,000-file budget. It is refused during Setup before
          compilation. Retrying the same archive cannot bypass the limit; the
          message is not evidence that disk space is full or your Go source is
          invalid.
        </p>
        <p>
          Use a compatible smaller version or dependency only when project
          requirements allow, or build that project in a desktop Go environment.
          Passing archive checks does not guarantee WASI compatibility, and this
          example does not establish Memos or SQLite support.
        </p>
        <details>
          <summary>How are large archives handled?</summary>
          <p>
            Above 160 MiB uncompressed, hashing can stream one entry at a time.
            When relevant Go source exceeds 48 MiB and the imported package is
            known, retention can narrow to that package and its in-module
            imports. 48 MiB is a selection trigger, not an absolute final
            project cap. These paths do not bypass the file-count and
            uncompressed-size checks.
          </p>
        </details>
        <p>
          <a href={`${github}/blob/main/docs/PACKAGES.md`}>
            Read the complete package documentation ↗
          </a>{" "}
          ·{" "}
          <Link href="/blog/why-a-small-module-zip-can-hit-a-limit">
            Why a small ZIP can hit a limit
          </Link>
        </p>
      </section>
      <section className="reading-section">
        <h2>App and web availability</h2>
        <p>
          <strong>
            {releases.public.version} ({releases.public.build}) is available on
            the App Store.
          </strong>{" "}
          It includes 171 teaching lessons in 21 units, 124 readings, 22
          prediction challenges and 88 interview guides.
        </p>
        <p>
          The web library adds fifteen readings on JSON v2, modern concurrency,
          SQL services and coding agents: 186 teaching lessons, 139 readings and
          22 challenges in 23 units. Interview has 92 guides and twelve
          algorithm labs. Native {releases.next.version} ({releases.next.build})
          is {releases.next.status.toLowerCase()}. See{" "}
          <Link href="/updates">version history</Link>
          and the <Link href="/guide">complete app guide</Link>.
        </p>
        <p>
          Web progress stays in this browser and is independent of app progress.
          Web completion marks are self-reported; this site does not compile
          arbitrary source. Eight{" "}
          <Link href="/interview/ai.workflow">Go coding-agent guides</Link>{" "}
          cover practical use of Codex, Claude and Cursor.
        </p>
        <a href={appStore} className="button secondary">
          View the app ↗
        </a>
      </section>
      <section className="reading-section">
        <h2>Reporting a Duo layout problem</h2>
        <p>
          Include the posture (closed, open, book or laptop), orientation,
          selected pane, whether the touch keyboard was visible and whether an
          external keyboard was connected. Files should be a collapsible left
          sidebar. These details help distinguish a posture issue from a
          keyboard inset or safe-area issue.
        </p>
      </section>
    </article>
  );
}
