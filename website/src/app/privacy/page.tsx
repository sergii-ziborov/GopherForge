import type { Metadata } from "next";
export const metadata: Metadata = {
  title: "Privacy",
  description:
    "Native app privacy, local browser learning progress and website infrastructure logs.",
  alternates: { canonical: "/privacy" },
};
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
        Updated 20 October 2026. Contact:{" "}
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
        Reading lessons and articles needs no account. Completion IDs and the
        last lesson can be saved in this browser’s local storage. They are not
        synced with app progress or uploaded as a user profile. Reset local
        progress in the course library or clear this site’s browser storage to
        remove it. No registration or cloud backup is provided.
      </p>
      <p>
        Self-check answers are handled in your browser. Copying source copies it
        to your device clipboard. The website does not run or upload code to a
        compiler service. Browser progress storage is optional; lessons remain
        readable if storage is blocked.
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
