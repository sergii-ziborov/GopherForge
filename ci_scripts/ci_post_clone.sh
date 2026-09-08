#!/bin/bash
set -euo pipefail

# Xcode Cloud runs this after cloning and before it resolves the project.
#
# A clean checkout is missing two things a local build takes for granted: the
# Xcode project, which XcodeGen generates from project.yml, and the Go
# toolchain, which is 220 MB of WebAssembly that does not live in git. Both are
# produced here, the same way for every cloud build, so what Apple archives is
# decided by this file and a pinned artifact rather than by whichever machine
# ran last.
#
# The toolchain is fetched as a distribution build: a named release asset,
# checked against its SHA-256, and refused if it carries any Go but the one
# the release notes claim. That is the reproducibility gate the repository
# already had; the cloud is simply the first place it is mandatory.

export HOMEBREW_NO_AUTO_UPDATE=1
for dependency in xcodegen zstd; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    brew install "$dependency"
  fi
done

cd "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud checkout path is required}"

xcodegen generate

export GOPHERFORGE_DISTRIBUTION_BUILD=1
export GOPHERFORGE_TOOLCHAIN_URL="https://github.com/sergii-ziborov/GopherForge/releases/download/toolchain-go1.27.1-wasm-1/go-wasm-toolchain.tar.zst"
export GOPHERFORGE_TOOLCHAIN_SHA256="e260dc4d45c3b405ce0da94a4742ed5b02a60dfd6e5bbf0e025934044d714ebf"
export GOPHERFORGE_EXPECTED_GO_VERSION="go1.27.1"
export GOPHERFORGE_TOOLCHAIN_TAG="go1.27.1-wasm-1"
./scripts/fetch_toolchain.sh
