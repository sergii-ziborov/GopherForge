import { pageMetadata } from "@/lib/page-metadata";
import type { Metadata } from "next";
export const metadata: Metadata = pageMetadata(
  "/privacy",
  "Privacy",
  "Native app privacy, local browser learning progress and website infrastructure logs.",
);
export default function Privacy() {
  return (
    <article className="page article legal">
      <p className="eyebrow">PRIVACY</p>
      <h1>
        Your work.
        <br />
        <em>Your choice.</em>
      </h1>
      <p>
        Updated 5 November 2026. Contact:{" "}
        <a href="mailto:sergii.ziborov@gmail.com">sergii.ziborov@gmail.com</a>.
      </p>
      <h2>The native app</h2>
      <p>
        GopherForge has no account, ads or tracking SDKs. Compilation and
        execution happen on device. Projects stay on the device or a
        user-selected Files/iCloud location. Sharing or exporting sends the
        content to the destination you choose.
      </p>
      <p>
        Optional GitHub and module downloads contact those services. Official
        reference links open external sites. Imported HTML or JavaScript in
        local web previews may contact remote services. Those providers apply
        their own policies. The app does not send source to a remote compiler.
      </p>
      <h2>Learning on this website</h2>
      <p>
        Reading lessons and articles needs no account. Completion IDs, interview
        self-assessments, and your last opened lesson or interview section can
        be saved in this browser’s local storage. They are not synced with app
        progress or uploaded as a user profile. Reset course completion in the
        course library, clear individual interview marks on a guide, or clear
        this site’s browser storage to remove all local study data. No
        registration or cloud backup is provided.
      </p>
      <p>
        Self-check answers are handled in your browser. Copying source copies it
        to your device clipboard. Playground compiles and runs Go locally in a
        browser worker after downloading verified compiler assets. Source and
        captured input stay on this device unless you create a room or
        deliberately share them. It does not upload code to a remote compiler
        service. Browser progress storage is optional; lessons remain readable
        if storage is blocked.
      </p>
      <p>
        Explicit Go dependency preparation contacts proxy.golang.org and
        sum.golang.org. These services receive public module names/versions and
        normal network metadata, not project source or stdin. Verified module
        downloads and compiler assets may be cached in this browser.
      </p>
      <h2>Optional Playground and published progress</h2>
      <p>
        Playground offers two room types. Encrypted browser rooms encrypt
        source, Output and participant/cursor state with AES-256-GCM before
        sending it. Nicknames are self-chosen display labels, shown alongside
        cursors, recent changes and results. They are not verified identities.
        Their key stays in the link fragment; the relay receives ciphertext and
        room/role metadata. Anyone with a complete Edit/View link and key has
        its role. The site delivers the browser code, so encryption does not
        protect against a compromised site or participant. Compatible native/MCP
        rooms send source, participant labels and Output to the relay in
        readable form. Connected AI providers can process compatible-room
        content under their policies. Both room types remain in process memory
        until expiry, closure or a restart, and are not backups. Browser drafts
        and encrypted-room recovery copies are kept in ordinary local browser
        storage. No account or personal directory is created.
      </p>
      <p>
        Publishing a progress link separately uploads a read-only snapshot of
        lesson IDs, reported compiler marks, interview self-assessments and
        saved places. It excludes source, drafts, attempts, names and device
        identifiers. Anyone holding the unlisted link can read it, including an
        AI tool. Access expires after 90 days or earlier revocation. It does not
        update automatically or alter another reader’s progress. Keep the
        revocation key on the publishing device. Private snapshot URLs are
        excluded from the sitemap and marked noindex; that does not prevent
        recipients copying their contents.
      </p>
      <p>
        The optional GopherForge JavaScript MCP companion decrypts encrypted
        room data on the agent&apos;s machine and keeps its key in a private
        local connection file or environment. Its source, Output, request
        history and named cursors remain encrypted on the relay. The MCP host
        and your selected AI provider can read the decrypted tool results. The
        companion uses GopherForge&apos;s encrypted protocol; it does not turn
        the compatible HTTPS connector into an encrypted connection.
      </p>
      <h2>Hosting and traffic analytics</h2>
      <p>
        The website runs on Hetzner infrastructure and uses Hostwatch’s
        access-log analytics. The website includes no third-party advertising or
        browser-tracking script and sets no analytics cookies. The server and
        reverse proxy can process the time, requested path, response status,
        duration, user agent and client IP for delivery, security and aggregate
        traffic reporting. This is server-side operational data, not a learning
        profile.
      </p>
      <p>
        The deployed access-log format omits query strings and referrers to
        avoid recording search terms. Log retention and access controls are
        configured by the hosting operator. Only the operator can access the
        infrastructure dashboard; the website exposes no analytics dashboard or
        administrative credentials publicly.
      </p>
      <h2>External links and contact</h2>
      <p>
        App Store, GitHub and references open other providers. If you contact
        support, the information you choose to send is used to answer and
        investigate that request. Avoid sending credentials or unnecessary
        private source. For privacy questions or requests, contact the email
        above.
      </p>
    </article>
  );
}
