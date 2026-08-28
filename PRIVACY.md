# GopherForge Privacy Policy

_Last updated: 27 August 2026_

GopherForge does not collect your personal data. There is no account, no
analytics, no advertising, no tracking, and no crash reporter.

## What stays on your device

Everything you make and everything the app records about your learning:

- Projects, their files, and their build history
- Lesson attempts, quiz and drill results, and the achievements they earn
- Settings such as the theme and the editor's text size
- The build cache, which holds compiled artifacts so a rebuild is fast

These live in the app's own container on your device and in your device
backups, if you make them. They are never uploaded anywhere. Deleting the app
deletes them.

## When the app uses the network

GopherForge compiles and runs Go entirely on your device, with the toolchain
that ships inside the app. It does not need the network to do its job. It
contacts a server only when you ask it to, for one of these three things:

| You do this | The app contacts | It sends |
| --- | --- | --- |
| Search for a Go package | `deps.dev` (Google) | The words you typed |
| Install a package | `proxy.golang.org` and `sum.golang.org` (Google) | The module path and version |
| Import a GitHub repository | `codeload.github.com` (GitHub) | The repository URL you gave |

These are the public Go module infrastructure and GitHub's public download
endpoint. The app sends nothing about you with these requests — no identifier,
no account, no device information beyond what any HTTPS client necessarily
reveals to the server it is talking to. Those services have their own privacy
policies, and their operators may log requests as any web service does.

All of these connections use HTTPS.

## Game Center

If you choose to connect Game Center, your achievement progress is mirrored to
Apple's Game Center under your own Apple Account. This is optional, the app
never signs you in without you asking, and your badges are earned and kept on
the device whether or not you connect it. What is shared is handled by Apple
under Apple's privacy policy.

## Children

GopherForge is a programming tool. It collects no data from anybody, including
children.

## Changes

If this policy ever changes, the updated version will be published here and the
date above will change.

## Contact

Questions about this policy: sergii.ziborov@gmail.com
