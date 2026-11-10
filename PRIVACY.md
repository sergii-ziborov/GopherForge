# GopherForge Privacy Policy

_Last updated: 5 November 2026_

GopherForge has no account, advertising, tracking SDK or crash reporter.
Ordinary projects and learning progress stay on your device. Optional
Playground rooms, published progress links and support messages send the
information you choose to share, as described below.

## What stays on your device

Unless you deliberately share or export them, these stay on your device:

- Projects, their files, and their build history
- Lesson attempts, quiz and drill results, and the achievements they earn
- Settings such as the theme and the editor's text size
- The build cache, which holds compiled artifacts so a rebuild is fast

These normally live in the app’s own container and in your device backups,
if you make them. You can choose a project-library folder in Files, including
a location provided by iCloud Drive or another file provider. That provider’s
sync and privacy rules then apply to files you place there. GopherForge does
not send ordinary unshared projects to a compiler service or its developer.

You can explicitly export and share project files using the system share sheet.
Deleting the app removes its local app-container data; it may not remove files
you exported or placed in a separately selected folder. Settings also lets you
reset learning progress. Keep backups of projects you want to retain.

## When the app uses the network

GopherForge compiles and runs Go entirely on your device, with the toolchain
that ships inside the app. It does not need the network to do its job. It
makes optional requests when you ask it to, including:

| You do this | The app contacts | It sends |
| --- | --- | --- |
| Search for a Go package | `deps.dev` and `api.deps.dev` (Google) | The words you typed |
| Install a package | `proxy.golang.org` and `sum.golang.org` (Google) | The module path and version |
| Import a GitHub repository | `codeload.github.com` (GitHub) | The repository URL you gave |
| Create or join a Playground room | `gopherforge.app` | Shared source, Output, participant labels, cursors and change summaries; encrypted room payloads are encrypted before delivery |
| Publish a progress snapshot | `gopherforge.app` | The previewed lesson IDs, compiler marks, interview self-assessments and saved places |

These are the public Go module infrastructure and GitHub's public download
endpoint. Package and repository downloads send no app account or advertising
identifier. As with any HTTPS connection, the destination can receive an IP
address and normal request metadata. Those services have their own privacy
policies, and their operators may log requests as any web service does.

All of these connections use HTTPS.

## Local website previews and external links

Website examples use an on-device server at `127.0.0.1` and WebKit. The local
preview does not expose a server on the public internet. HTML or JavaScript you
import can contain remote links or requests; using that content may contact
its chosen services. You control the projects and packages you import.

Opening the app's support, privacy, terms, Go-reference or App Store links
contacts the destination website through the system browser. If you contact
support by email, the developer receives the message and information you
choose to include. Do not send secrets or private source code unless needed
and agreed for the support request.

## Game Center

Game Center is not enabled. Achievements stay on your device and the app does
not ask you to sign in to Game Center.

## Product website

When you visit `gopherforge.app`, its hosting provider receives ordinary web
requests, including an IP address and browser request metadata, to deliver the
site. Hosting infrastructure may retain operational or security logs under
its own policies. The website does not ask you to create an account, and we do
not add advertising trackers. Native-app source or progress is uploaded only
through the optional sharing actions described here.
External App Store, GitHub and documentation links have their own policies.

The optional `gopherforge-mcp` JavaScript companion runs beside the agent on a
computer or trusted execution host. It keeps an encrypted room's key in a
private local connection file or process environment and encrypts source,
reported Output, requests, change history and named cursor presence before
relay delivery. The configured MCP host and selected AI provider receive the
decrypted tool results. The remote compatible HTTPS MCP remains a separate
mode whose relay can read shared content.

## Children

GopherForge is a programming tool with no child accounts or advertising.
Optional sharing works as described here for every user. Do not put sensitive
personal information in a nickname, shared source, Output or support request.

## Changes

If this policy ever changes, the updated version will be published here and the
date above will change.

## Contact

Questions about this policy: sergii.ziborov@gmail.com


## Optional collaboration and published progress

The 1.3.3 implementation asks for a participant nickname when creating or joining
a Playground room. It is a self-chosen display label, not a verified identity or
account. Clients display names beside cursors, recent file changes and new run
results. The chosen label can be kept as a local preference and changed in the
room. Avoid entering a real name if you prefer a pseudonym.

Encrypted rooms encrypt source, Output and nickname/cursor state with
AES-256-GCM before delivery. The key stays in the link fragment and is not sent
to the relay. Native CryptoKit and a bundled Yjs model use the same protocol as
the website. The relay still processes room/role credentials, ciphertext sizes,
timing and network metadata. Participants holding a complete link/key can read
its content. A compromised participant or replacement browser code can expose
content. Native recovery files use protected app storage; room encryption is
separate from device at-rest protection.

Compatible rooms for released apps and remote MCP retain readable source,
participant labels/cursors, change summaries and Output on the temporary relay.
An MCP assistant can join with a display label and process allowed shared content
under its provider’s policy. Remote MCP does not receive encrypted-room keys.
No connection, edit, cursor or request automatically executes code. A person
presses the local execution control.

Explicit package preparation sends public module names/versions to Go package
services and keeps verified compatible dependency source separately on the
device. Project source and stdin are not sent to those providers. Room expiry,
owner closure or a relay restart can end sharing; keep an independent project
copy. The public 1.3.2 app uses compatible rooms; native 1.3.3 adds encrypted
rooms. A nickname is associated with that participant’s source edits, cursor
and reported results inside the room, even though no account is created.

Publishing a progress link is a separate explicit action. The previewed
snapshot contains lesson IDs, reported compiler marks, interview marks and
saved places, and excludes source, drafts, attempts, names and device IDs. It
remains readable to anyone holding its unlisted link for up to 90 days or until
you revoke it from the publishing device. It does not update automatically.
The server stores the snapshot to serve that link; it is not a cloud backup.
