# GopherForge Privacy Policy

_Last updated: 10 October 2026_

GopherForge does not collect your personal data. There is no account, no
analytics, no advertising, no tracking, and no crash reporter.

## What stays on your device

Everything you make and everything the app records about your learning:

- Projects, their files, and their build history
- Lesson attempts, quiz and drill results, and the achievements they earn
- Settings such as the theme and the editor's text size
- The build cache, which holds compiled artifacts so a rebuild is fast

These normally live in the app’s own container and in your device backups,
if you make them. You can choose a project-library folder in Files, including
a location provided by iCloud Drive or another file provider. That provider’s
sync and privacy rules then apply to files you place there. GopherForge does
not send your projects to a compiler service or its developer.

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

These are the public Go module infrastructure and GitHub's public download
endpoint. The app sends nothing about you with these requests — no identifier,
no account, no device information beyond what any HTTPS client necessarily
reveals to the server it is talking to. Those services have their own privacy
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

This policy's no-collection statement describes the native application. When
you visit `gopherforge.app`, its hosting provider receives ordinary web
requests, including an IP address and browser request metadata, to deliver the
site. Hosting infrastructure may retain operational or security logs under
its own policies. The website does not ask you to create an account, and we do
not add advertising trackers or send native-app project or learning data to it.
External App Store, GitHub and documentation links have their own policies.

## Children

GopherForge is a programming tool. It collects no data from anybody, including
children.

## Changes

If this policy ever changes, the updated version will be published here and the
date above will change.

## Contact

Questions about this policy: sergii.ziborov@gmail.com
