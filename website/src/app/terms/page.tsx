import type { Metadata } from "next";
import Link from "next/link";
export const metadata: Metadata = {
  title: "Terms of Use",
  description:
    "Product scope, purchase terms and educational content terms for GopherForge.",
  alternates: { canonical: "/terms" },
};
export default function Terms() {
  return (
    <article className="page article legal">
      <p className="eyebrow">TERMS OF USE</p>
      <h1>
        A few practical
        <br />
        <em>details.</em>
      </h1>
      <p>Updated 19 October 2026. GopherForge is made by Serhii Ziborov.</p>
      <h2>The native application</h2>
      <p>
        The app is a one-time paid App Store purchase, with no subscription or
        in-app purchase. Localized prices and purchase/refund handling are
        provided by Apple. Apple’s{" "}
        <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">
          standard application EULA
        </a>{" "}
        applies to the licensed app.
      </p>
      <h2>Tools and compatibility</h2>
      <p>
        The app provides a bounded on-device Go environment. Not every module or
        program is supported. cgo, native assembly, guest networking, module
        archive budgets and other boundaries are described in{" "}
        <Link href="/support#package-limits">Support</Link>. A lesson about a
        shell, container or cluster is educational material for your own
        environment and does not add those capabilities to the iOS sandbox.
      </p>
      <h2>Web lessons and articles</h2>
      <p>
        The web library is readable without an account. Browser progress is
        local and may be lost when browser storage is cleared. It does not
        transfer completion to the app. Code exercises and self-checks are
        educational material; a web completion mark is not certification or
        proof that a compiler verified your code.
      </p>
      <p>
        Review commands, permissions and data before running examples.
        Architecture suitability ratings are editorial, scenario-dependent
        guidance, not benchmarks or guarantees. The website may include upcoming
        native course material; availability is labelled on the course and
        version-history pages.
      </p>
      <h2>Intellectual property and independence</h2>
      <p>
        GopherForge is proprietary software with publicly readable source.
        Public readability does not grant an open-source license to the
        application or its course. The repository’s license and third-party
        notices describe their respective terms. Go and the gopher belong to
        their respective owners; GopherForge is not affiliated with or endorsed
        by Google or the Go project.
      </p>
      <h2>Contact</h2>
      <p>
        For help, corrections or terms questions, contact{" "}
        <a href="mailto:sergii.ziborov@gmail.com">sergii.ziborov@gmail.com</a>.
        See <Link href="/privacy">Privacy</Link> for app and website data
        handling.
      </p>
    </article>
  );
}
