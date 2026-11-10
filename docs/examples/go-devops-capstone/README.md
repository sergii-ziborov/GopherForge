# Go DevOps capstone: prove one service change

Complete the six GopherForge DevOps readings, then return to this lab. The goal is a small, reviewable delivery loop with evidence. Go builds the service and its checks; deployment, monitoring and recovery still need explicit owners.

## Run the local model

Use Go 1.27 with the toolchain version recorded in your evidence. The project has no third-party dependencies. From this directory:

```sh
go run .
```

Expected output:

```text
not ready: 503
ready: 204
version: 200 {"revision":"local-review"}
```

The default mode uses `httptest` recorders and opens no network socket. Copy `main.go` into GopherForge to explore that mode. Listening, process signals, shell commands and the race detector belong in a native development environment, outside the app/browser sandbox.

## Verify and retain one artifact

On a native machine with a supported C compiler for Go's race detector:

```sh
./verify.sh
./build/service
go version -m ./build/service
shasum -a 256 ./build/service
```

The script runs independent contract tests, a race check and `go vet`, records the toolchain and a source manifest, and builds one executable. It embeds the manifest digest in `/version` and records the binary digest. Keep `build/toolchain.txt`, `build/sources.sha256`, `build/buildinfo.txt` and `build/service.sha256` with that exact executable. A source digest is an identifier, not a signature or a trusted build attestation. The `-revision` flag can override the label; the label alone never proves binary identity.

The same `./verify.sh` command can be a CI step after a clean checkout and installation of the reviewed Go/C toolchains. Restrict the job to the permissions it needs. A vulnerability check, provenance/signing policy and deployment approval are separate gates; this script does not establish them.

## Inspect the native service

In one terminal, run the verified artifact on loopback:

```sh
./build/service -serve -addr 127.0.0.1:8080
```

In another terminal:

```sh
curl --fail --silent --show-error http://127.0.0.1:8080/version
curl --fail --silent --show-error -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/readyz
curl --silent --show-error -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/missing
```

Expect the recorded revision, `204`, and `404`. Stop the first terminal with Ctrl-C. The server owner clears readiness, gives HTTP shutdown two seconds, closes on timeout and joins its serving goroutine. It does not own hypothetical application workers or hijacked connections. A real deployment also needs traffic draining and explicit ownership of those resources. The test suite checks readiness transitions directly; this lab does not simulate a production load balancer.

## Acceptance checklist

1. Add an optional `service` field to `/version`. Keep an independent test for the existing `revision` field so older clients remain compatible. Change the test expectation first, observe failure, then implement the field and rerun verification.
2. Demonstrate invalid configuration, an unknown route and readiness changing from `503` to `204` and back. Explain why liveness and readiness are different contracts.
3. Run the native cancellation test under `-race`. Record the process exit and explain which goroutine is joined, the shutdown deadline and what still needs a separate owner.
4. Record the exact verified binary digest and target environment. Promote those bytes; rebuilding for a later environment creates a different artifact that needs new evidence. Never use the `/version` label as a substitute for the artifact digest.
5. Draft a runbook with an observable symptom, first read-only checks, a reversible mitigation and a recovery check. Specify the success/error event and time window you would measure for an SLI; three local requests do not establish an SLO.
6. Write a recovery decision for the optional-field change. Explain compatibility and accepted-data handling. This lab has no database; it cannot prove that rolling back a real data migration preserves writes. Have another person follow the runbook in an environment you control.

Keep a short evidence file with commands, observed outcomes, source and artifact identities, target and remaining limits. A green test run is one input to a release decision. It is not evidence of a production rollout or a complete DevOps qualification.
