#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export GOTOOLCHAIN=local
mkdir -p build
go version > build/toolchain.txt
go test -race -count=1 ./...
go vet ./...
shasum -a 256 main.go main_test.go go.mod verify.sh > build/sources.sha256
source_id="$(shasum -a 256 build/sources.sha256 | cut -d ' ' -f 1)"
go build -trimpath -ldflags "-X main.buildRevision=$source_id" -o build/service .
shasum -a 256 build/service > build/service.sha256
go version -m build/service > build/buildinfo.txt
printf 'Verified one artifact. Review build/service.sha256 and retain these exact bytes.\n'
