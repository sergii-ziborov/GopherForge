# GopherForge support

## Contact

**Email:** <sergii.ziborov@gmail.com>

Apple asks the Support URL to lead to real contact information, and an issue
tracker is not that: filing an issue needs a GitHub account, and someone whose
build fails on a train has no reason to make one. The email is the first
channel; the tracker below is the second.

**Issue tracker:** <https://github.com/sergii-ziborov/GopherForge/issues>

## Before you write

Two things make almost any report answerable at once.

**The version.** Settings → About shows the version and build. It is the first
thing that distinguishes "this is fixed already" from "this is new".

**What the toolchain said.** Settings → Toolchain shows which Go release is
bundled and whether it is staged. If a build failed, the text in the Problems
or Output pane is the useful part — it is the compiler's own words, and it can
be selected and copied.

## What this app can and cannot build

GopherForge runs a real Go toolchain on the device, and the boundaries are
deliberate rather than accidental.

**Works:** pure Go, the standard library, multiple files and packages in one
module, table-driven tests, `go vet`, `gofmt`, and pure-Go dependencies
vendored as source.

**Does not work:** cgo, assembly (`.s`) files, and packages that need a C
toolchain — none of these can be compiled inside the sandbox. `//go:embed` of
non-Go assets is not carried through vendoring. Transitive dependencies are not
resolved recursively: if a module you add imports another module, that one has
to be added too. Opening a project reports what it found in a compatibility
summary rather than failing halfway through a build.

**Never happens:** no code leaves the device to be compiled. The compiler,
linker, vet and gofmt are in the app. The network is used only when you ask for
a package or import a repository.

## Privacy

The app collects nothing. The full policy is in
[PRIVACY.md](PRIVACY.md), and it is also linked from Settings inside the app.

## Reporting something that looks like a security problem

Please use email rather than a public issue, and say what you did and what
happened rather than only what you think the cause was.

## Lessons and iPhone Duo

Version 1.1 adds diagrams and practical notes to all 47 course lessons and 22
prediction challenges. Embedded lesson code scrolls with the page; Full screen
opens a code view that scrolls independently. Back to lesson keeps your edits.

On iPhone Duo with iOS 27.1 or later, laptop posture keeps Code or Terminal
above the hinge. Problems, Output, Tests and Idioms use the lower display in
place of the keyboard. The Projects button beside the workspace title provides
a way back while the keyboard hides the section bar.

If reporting a layout problem, include the device, system version, posture
(closed, open, or laptop), selected pane and whether the keyboard was visible.
Version 1.1 is being prepared for TestFlight verification and is not yet
available as an App Store update.

## Terms of Use

The app uses Apple's standard application EULA. Product details are in
[Terms of Use](https://gopherforge.app/terms).
