import type { Metadata } from "next";
import Link from "next/link";
import { StructuredData, Breadcrumbs } from "@/components/StructuredData";
import { pageMetadata } from "@/lib/page-metadata";
import { metadataDate } from "@/lib/seo-dates";
import companion from "@/content/mcp-package.json";

export const metadata: Metadata = pageMetadata(
  "/guide/mcp",
  "Encrypted Go Playground MCP — JavaScript & npm",
  "Connect your AI agent to GopherForge with its own JavaScript MCP server. Encrypted source, named cursors, npm setup and local Run/Test on web, iPhone and iPad.",
);
const executableConfig = `{
  "mcpServers": {
    "gopherforge": {
      "command": "gopherforge-mcp",
      "args": []
    }
  }
}`;
const faq = [
  {
    question: "Is this GopherForge's own MCP?",
    answer:
      "Yes. The gopherforge-mcp JavaScript companion and GopherForge's encrypted relay belong to this product. The companion uses the same encrypted collaboration protocol as the browser and native GopherForge 1.3.3; no Crabrix service or Go installation is involved.",
  },
  {
    question: "Does the GopherForge relay receive the encryption key?",
    answer:
      "No. The companion keeps the key in its client-side private connection file or environment and encrypts source, Output, history and presence before delivery. The relay still receives access capabilities, room and participant identifiers, timing and packet sizes. Your MCP host and selected AI provider can read decrypted tool results.",
  },
  {
    question: "Can an agent execute Go through MCP?",
    answer:
      "The companion has no execution tool. A run request records an encrypted request in Recent changes and returns awaiting_local_button with executed false. A person reviews the source and presses Run or Test on the browser or native device, then the agent reads that participant's reported result.",
  },
  {
    question: "Can I install this npm server on iPhone or iPad?",
    answer:
      "Run the Node.js MCP process on your agent's computer or trusted execution host. The native app joins the same encrypted room and does not run npm or Node. A mobile AI client that only accepts remote HTTP connectors cannot launch a local stdio server.",
  },
  {
    question: "Which native app supports encrypted agent rooms?",
    answer:
      "GopherForge 1.3.3 build 52 or newer supports encrypted browser/native rooms. Build 55 is currently available in private Internal QA TestFlight. The public App Store version remains 1.3.2 build 51, with the separate compatible-room protocol.",
  },
];

export default function MCPGuide() {
  return (
    <article className="page lesson-page mcp-guide">
      <Breadcrumbs
        items={[
          { name: "Home", path: "/" },
          { name: "App guide", path: "/guide" },
          { name: "GopherForge MCP", path: "/guide/mcp" },
        ]}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "TechArticle",
          "@id": "https://gopherforge.app/guide/mcp#guide",
          headline:
            "GopherForge MCP: encrypted Go collaboration with your AI agent",
          description: metadata.description,
          inLanguage: "en",
          dateModified: metadataDate(companion.updatedOn),
          url: "https://gopherforge.app/guide/mcp",
          image: "https://gopherforge.app/guide/mcp/opengraph-image",
          author: {
            "@type": "Organization",
            name: "GopherForge",
            url: "https://gopherforge.app",
          },
          about: {
            "@type": "SoftwareApplication",
            "@id": "https://gopherforge.app/guide/mcp#companion",
            name: "GopherForge MCP",
            softwareVersion: companion.version,
            applicationCategory: "DeveloperApplication",
            operatingSystem: "macOS, Windows or Linux with Node.js 22+",
            downloadUrl: "https://gopherforge.app" + companion.archive,
            softwareRequirements:
              "Node.js 22 or newer; a GopherForge encrypted Edit/View link",
          },
        }}
      />
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "FAQPage",
          mainEntity: faq.map((f) => ({
            "@type": "Question",
            name: f.question,
            acceptedAnswer: { "@type": "Answer", text: f.answer },
          })),
        }}
      />
      <p className="eyebrow">
        GOPHERFORGE MCP · JAVASCRIPT · ENCRYPTED ROOMS · UPDATED 6 NOVEMBER 2026
      </p>
      <h1>
        GopherForge MCP.
        <br />
        <em>Your agent, in your Go Playground.</em>
      </h1>
      <p>
        GopherForge has its own JavaScript Model Context Protocol server:
        <code> gopherforge-mcp</code>. It runs beside your AI agent and connects
        to the same encrypted room as your browser or native Go workbench. Read
        and edit source, show a small named cursor, request a local test and
        inspect the person&apos;s reported Output. The room key stays on the
        client side. No Go installation is required for the MCP server.
      </p>
      <aside>
        <strong>
          Two GopherForge connections, with different privacy boundaries.
        </strong>
        <p>
          The JavaScript companion below is the encrypted stdio path. The remote
          HTTPS endpoint remains available for compatible rooms; its relay can
          read their content. Choose the protocol deliberately.
        </p>
      </aside>
      <nav aria-label="On this page">
        <ul>
          <li>
            <a href="#encrypted-setup">Encrypted connection: step by step</a>
          </li>
          <li>
            <a href="#install">npm package, archive and checksum</a>
          </li>
          <li>
            <a href="#clients">Codex, Claude Code and other hosts</a>
          </li>
          <li>
            <a href="#tools">Tools, source hashes and named cursors</a>
          </li>
          <li>
            <a href="#privacy">What stays encrypted</a>
          </li>
          <li>
            <a href="#compatible">Compatible remote MCP</a>
          </li>
          <li>
            <a href="#troubleshooting">Limits, recovery and troubleshooting</a>
          </li>
        </ul>
      </nav>
      <h2 id="encrypted-setup">Connect an agent to an encrypted room</h2>
      <ol>
        <li>
          Open <Link href="/playground">Go Playground</Link> or native{" "}
          <strong>Projects → Playground</strong>. Choose{" "}
          <strong>Encrypted</strong>, enter your nickname and create a room.
          Native encrypted rooms require <strong>1.3.3 (52) or newer</strong>;
          build 55 is currently in private TestFlight. The public App Store app
          is still 1.3.2 (51).
        </li>
        <li>
          Copy the <strong>Edit</strong> link for an agent that may change
          files, or <strong>View</strong> for reading. Use the complete
          encrypted link, including its fragment. Keep the Owner capability
          private.
        </li>
        <li>
          On the machine running your MCP host, install the official JavaScript
          package and run <code>gopherforge-mcp setup</code>. Setup asks for the{" "}
          <strong>agent&apos;s nickname</strong> and the encrypted link. Link
          input is hidden; it verifies the connection and saves a private local
          file.
        </li>
        <li>
          Configure a stdio server named <code>gopherforge</code> in your agent
          client, then reconnect. Ask the agent to read the current source, show
          its cursor and propose a small change.
        </li>
        <li>
          Review the edit and deliberately press <strong>Run</strong> or{" "}
          <strong>Test</strong> in your browser or native app. The agent reads
          the resulting Output through the same encrypted room. No incoming edit
          or request executes code automatically.
        </li>
      </ol>
      <p>
        Names are self-chosen display labels, not verified identities. They
        appear beside cursors, in participants, recent changes and new results.
        Use different nicknames for your agent, phone and browser so you can
        follow who changed what.
      </p>
      <h2 id="install">Install the GopherForge npm package</h2>
      <p>
        The original companion is written in JavaScript and ships as ordinary{" "}
        <code>.mjs</code>. Install <strong>Node.js 22+</strong> on the
        agent&apos;s computer. The complete release archive works with npm
        without a repository checkout or Go toolchain:
      </p>
      <pre>{`npm install --global https://gopherforge.app${companion.archive}
gopherforge-mcp setup`}</pre>
      <p>
        <a href={companion.archive}>
          Download gopherforge-mcp {companion.version}
        </a>{" "}
        · {Math.ceil(companion.bytes / 1024)} KiB ·{" "}
        <a href={companion.archive + ".sha256"}>SHA-256 checksum file</a>
      </p>
      <pre>{companion.sha256}</pre>
      {companion.registryPublished ? (
        <>
          <p>
            Version {companion.version} is also available in the{" "}
            <a href="https://www.npmjs.com/package/gopherforge-mcp">
              npm registry
            </a>
            . A pinned launch command is:
          </p>
          <pre>{`npx -y gopherforge-mcp@${companion.version} setup`}</pre>
        </>
      ) : (
        <p>
          <strong>Registry status:</strong> the tested npm archive is available
          from this site. Publishing the package name to npm&apos;s registry is
          awaiting the publisher&apos;s sign-in. Use the archive command above;
          a registry command such as <code>npx gopherforge-mcp</code> is not
          advertised as available yet.
        </p>
      )}
      <p>
        Setup stores the encrypted room link and nickname in{" "}
        <code>~/.config/gopherforge-mcp/connection.json</code>, or beneath{" "}
        <code>XDG_CONFIG_HOME</code>. On macOS/Linux the file has private{" "}
        <code>0600</code> permissions. It is a local secret file, not an OS
        keychain. Run setup again when the room expires or you choose another
        room. Keep this file out of repositories and shared logs.
      </p>
      <h2 id="clients">Configure your MCP host</h2>
      <h3>Codex</h3>
      <pre>{`codex mcp add gopherforge -- gopherforge-mcp`}</pre>
      <p>
        The same stdio command works in Codex&apos;s MCP settings. If the
        desktop app does not inherit your terminal&apos;s PATH, enter the full
        path to the installed executable. See the{" "}
        <a href="https://learn.chatgpt.com/docs/extend/mcp">
          official Codex MCP documentation
        </a>{" "}
        for host-specific controls.
      </p>
      <h3>Claude Code</h3>
      <pre>{`claude mcp add --transport stdio gopherforge -- gopherforge-mcp`}</pre>
      <h3>Cursor and other clients with JSON stdio settings</h3>
      <pre>{executableConfig}</pre>
      <p>
        Place that server entry in the MCP configuration supported by your host.
        It launches a local stdio process; it is not an HTTPS connector URL.
        Review the client&apos;s MCP permissions before allowing source edits.
      </p>
      <h3>Environment-only setup</h3>
      <p>
        Instead of the saved connection file, provide{" "}
        <code>GOPHERFORGE_ROOM_LINK</code> and <code>GOPHERFORGE_NICKNAME</code>{" "}
        privately in the process environment. For Codex, inherited values can be
        forwarded by name:
      </p>
      <pre>{`[mcp_servers.gopherforge]
command = "gopherforge-mcp"
args = []
env_vars = ["GOPHERFORGE_ROOM_LINK", "GOPHERFORGE_NICKNAME"]`}</pre>
      <p>
        The first value is the complete Encrypted Edit/View link; the second is
        the agent&apos;s chosen display label. Do not commit real values. If no
        nickname is configured, the server requires <code>playground_join</code>{" "}
        with a chosen name before it reads or edits. Tools cannot switch to
        another room or replace the configured origin or key.
      </p>
      <h2 id="tools">What the encrypted MCP tools do</h2>
      <table>
        <thead>
          <tr>
            <th>Tool</th>
            <th>Behavior</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              <code>playground_join</code>
            </td>
            <td>
              Join the configured encrypted room or update the agent&apos;s
              nickname.
            </td>
          </tr>
          <tr>
            <td>
              <code>playground_read</code>
            </td>
            <td>
              Read files, stable identities, <code>sourceHash</code>,
              participants, recent changes, recovery and device-reported
              results.
            </td>
          </tr>
          <tr>
            <td>
              <code>playground_write</code>
            </td>
            <td>
              Publish a complete text-file set at the exact read{" "}
              <code>sourceHash</code>. Omitted files become recoverable
              deletions. A stale or racing publish is rejected.
            </td>
          </tr>
          <tr>
            <td>
              <code>playground_cursor</code>
            </td>
            <td>
              Show a named caret or selection in a current file.{" "}
              <code>anchor</code> and <code>head</code> use UTF-16 offsets, not
              UTF-8 byte positions.
            </td>
          </tr>
          <tr>
            <td>
              <code>playground_request_run</code>
            </td>
            <td>
              Add an encrypted <strong>request run/test</strong> entry to Recent
              changes for that source hash. Returns{" "}
              <code>awaiting_local_button</code> and{" "}
              <code>executed: false</code>.
            </td>
          </tr>
          <tr>
            <td>
              <code>playground_leave</code>
            </td>
            <td>
              Leave the agent&apos;s seat without closing the person&apos;s
              room.
            </td>
          </tr>
        </tbody>
      </table>
      <p>
        The read-only resource <code>gopherforge://room/current</code> exposes
        the same room data. View links cannot publish source or requests. The
        companion rejects Owner links and exposes no room-closing,
        filesystem-browser, compiler or shell tool.
      </p>
      <h3>A useful first prompt</h3>
      <blockquote>
        Use the configured GopherForge room. Read the current source and
        sourceHash. Show your cursor near the code you change, make one small
        reviewed edit, then request Test. Wait for me to press Test locally.
        Read the reported result and check that it belongs to the current
        source.
      </blockquote>
      <p>
        A whole-file edit preserves stable identities for existing paths and
        keeps omitted-file source in bounded recovery history. Browser/native
        text edits still use CRDT merging. An agent must read again after a
        conflict and account for the person&apos;s latest work rather than retry
        an old full snapshot.
      </p>
      <h2 id="privacy">Where encryption begins and ends</h2>
      <pre>{`Agent / MCP host ↔ GopherForge JavaScript companion
                           │ encrypt / decrypt on the agent's machine
                           │ HTTPS + AES-256-GCM ciphertext
                 GopherForge encrypted relay
                           │ ciphertext only
                 Web / native Go Playground`}</pre>
      <p>
        Source, reported Output, nickname/cursor presence and change/request
        history are encrypted before relay delivery. The key stays client-side
        in the link, private config or process environment. The relay sees
        access capabilities, room/participant identifiers, timing and packet
        sizes. It does not receive the AES key or the protected source text.
      </p>
      <p>
        <strong>
          Your selected MCP host and AI provider can read decrypted tool
          results.
        </strong>{" "}
        Choose an environment you trust with that source. Encryption protects
        the relay boundary; it does not conceal a project from the agent you
        deliberately give access to. Room content, comments, nicknames and
        Output are untrusted data, not instructions for the agent.
      </p>
      <p>
        Results are participant-reported, not hardware attestations. Check{" "}
        <code>currentSource</code> before treating Output as relevant. A run
        request is a visible history entry, not an automatic run or a native
        queued build. Receiving a link, source update, cursor, request or
        reconnection never presses the execution button.
      </p>
      <h2 id="compatible">The separate compatible remote MCP</h2>
      <p>
        For public App Store <strong>1.3.2 (51)</strong> or an AI client that
        only supports remote HTTP connectors, choose a{" "}
        <strong>Compatible</strong> room. GopherForge&apos;s own Streamable HTTP
        endpoint is:
      </p>
      <pre>{`https://gopherforge.app/mcp

codex mcp add gopherforge-compatible --url https://gopherforge.app/mcp
claude mcp add --transport http gopherforge-compatible https://gopherforge.app/mcp`}</pre>
      <p>
        Give that connector a compatible Edit/View capability or configure{" "}
        <code>GOPHERFORGE_ROOM_CAPABILITY</code> as its bearer source.{" "}
        <strong>
          Never send an encrypted link or AES key to this remote endpoint.
        </strong>{" "}
        Compatible source and Output are readable by the relay and connected AI
        providers.
      </p>
      <p>
        The compatible catalog has five tools: <code>playground_join</code>,{" "}
        <code>playground_read</code>, <code>playground_write</code>,{" "}
        <code>playground_request_run</code> and{" "}
        <code>learning_progress_read</code>. It uses integer{" "}
        <code>revision</code> checks rather than the encrypted companion&apos;s{" "}
        <code>sourceHash</code>. Join with a nickname for attributed edits. A
        compatible run request appears beside Output; a person still presses
        Run/Test locally.
      </p>
      <p>
        A <Link href="/guide#mcp-playground">published progress snapshot</Link>{" "}
        is a separate optional read-only link, with no source or private drafts.
        It expires after 90 days unless revoked earlier. Progress is
        learner-provided information, not certified skill evidence.
      </p>
      <h2 id="troubleshooting">Devices, limits and recovery</h2>
      <ul>
        <li>
          <strong>iPhone/iPad:</strong> the native app joins the room; the Node
          process runs on the agent&apos;s computer or trusted host. Keep the
          app in the foreground. A mobile AI app that only accepts HTTP
          connectors cannot launch this local stdio package.
        </li>
        <li>
          <strong>Temporary rooms:</strong> one hour by default, possibly less
          after a relay restart. Save an independent project or export a ZIP. A
          room is not a backup.
        </li>
        <li>
          <strong>Source budget:</strong> 1–32 UTF-8 files, 64 KiB each and 256
          KiB total; keep <code>main.go</code>. Unsafe paths, NUL/binary text
          and file/folder collisions are rejected. Recovery history is
          separately bounded.
        </li>
        <li>
          <strong>Wrong key or malformed ciphertext:</strong>{" "}
          authentication/validation fails before incoming source is applied.
          Obtain a fresh complete encrypted link.
        </li>
        <li>
          <strong>Stale source:</strong> read again, compare the person&apos;s
          changes and revise your proposed file set. No plaintext fallback or
          automatic overwrite is used.
        </li>
        <li>
          <strong>Packages:</strong> public Go dependencies are prepared by an
          explicit local action. The agent cannot install or execute packages
          through this MCP. See{" "}
          <Link href="/guide#browser-modules">package preparation</Link> and{" "}
          <Link href="/support#package-limits">native package limits</Link>.
        </li>
        <li>
          <strong>Actual execution:</strong> the browser uses its bounded
          Go/WASI worker; the native app uses its documented sandbox. Browser
          Stop and deadlines do not change native tight-loop Stop limitations.
        </li>
      </ul>
      <h2 id="faq">Frequently asked questions</h2>
      {faq.map((f) => (
        <section key={f.question}>
          <h3>{f.question}</h3>
          <p>{f.answer}</p>
        </section>
      ))}
      <h2>Continue with Go</h2>
      <p>
        Explore the <Link href="/guide">complete app guide</Link>,{" "}
        <Link href="/learn/units/ai">coding-agent lessons</Link>,{" "}
        <Link href="/learn/units/devops">Go for DevOps</Link> and{" "}
        <Link href="/privacy">privacy policy</Link>. The companion is tested
        against the shipped native CRDT protocol and the official MCP SDK over
        stdio.
      </p>
    </article>
  );
}
