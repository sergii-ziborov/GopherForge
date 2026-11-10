import Link from "next/link";
import courses from "@/content/course-downloads.json";
import { pageMetadata } from "@/lib/page-metadata";
import { Breadcrumbs } from "@/components/StructuredData";

export const metadata = pageMetadata(
  "/downloads",
  "Complete Go and DevOps Course Downloads",
  "Download complete GopherForge courses for explicit offline installation: Go, DevOps terminal labs and interview preparation. Includes versioned files and SHA-256 checksums.",
);

export default function Downloads() {
  return (
    <div className="page downloads-page">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "Course downloads", path: "/downloads" },
        ]}
      />
      <h1>Complete course downloads</h1>
      <p>
        Choose a whole course, download it once and study offline. Lessons do
        not fetch their content as you open them.
      </p>
      <p>
        Complete course downloads are supported in 1.3.3 build 55, available in
        private Internal QA TestFlight. The public 1.3.2 app uses its bundled
        curriculum. The Go compiler stays part of the app.
      </p>
      <div className="download-grid">
        {courses.map((course) => (
          <section className="download-card" key={course.id}>
            <h2>{course.title}</h2>
            <p>{course.summary}</p>
            <p>
              {course.interviewCount > 0
                ? `${course.interviewCount} interview guides and 12 algorithm walkthroughs.`
                : `${course.unitCount} units, ${course.teachingCount} teaching lessons, ${course.challengeCount} prediction challenges${course.labCount ? ` and ${course.labCount} terminal labs` : ""}.`}
            </p>
            <p>
              {(course.byteCount / 1024 / 1024).toFixed(2)} MiB · revision{" "}
              {course.revision}
            </p>
            <p>
              <a
                className="button primary"
                href={`/downloads/courses/${course.fileName}`}
                download
              >
                Download complete course
              </a>
            </p>
            <p>
              <a href={`/downloads/courses/${course.fileName}.sha256`}>
                SHA-256 checksum
              </a>
            </p>
            <code style={{ overflowWrap: "anywhere" }}>{course.sha256}</code>
          </section>
        ))}
      </div>
      <section className="reading-section download-instructions">
        <h2>Install, export and remove</h2>
        <p>
          In build 55, open Learn → Course downloads. Choose Download complete
          course, or import the full JSON file from Files. The app verifies the
          version, size and checksum before installing the whole document.
          Interrupted downloads preserve the previous installed version.
        </p>
        <p>
          Export complete course saves a byte-identical copy for later offline
          import. Personal progress, drafts and lab files are kept separately.
          Remove download frees the study content and keeps that personal work.
          New revisions require another explicit complete download.
        </p>
        <h2>What the DevOps terminal executes</h2>
        <p>
          The native terminal playground and six guided labs execute a bounded
          shell subset over private /lab files in WASI. Practice files, quoted
          arguments, variables, redirects, buffered pipelines, conditions and
          scripts. Independent checks inspect the resulting files and artifact
          hashes.
        </p>
        <p>
          The local lab has no network, host processes, Docker, kubectl, SSH or
          package installer. Real infrastructure exercises need an owned
          disposable native environment. Source, steps, memory, output and
          storage are bounded; Stop and Reset apply to the current lab.
        </p>
        <p>
          <Link href="/learn/units/devops">Study DevOps and reliability</Link> ·{" "}
          <Link href="/guide">Read the app guide</Link>
        </p>
      </section>
    </div>
  );
}
