## A stream is not a complete application message

A CSV importer works in a small test and silently drops the final record in production. An HTTP endpoint accepts the first JSON object in a request and ignores a second object after it. A log processor reports success after a long line stops its scanner. These failures look unrelated, but each confuses one boundary with another: a read call, an input budget, a token, a document, or a completed business operation.

This guide builds a practical model for those boundaries. The objective is not to replace every standard helper with a custom loop. It is to understand what the helper promises and what the application must still decide. Reading bytes successfully does not establish that the message was complete, valid, small enough, or safe to commit to a database.

The downloadable lab contains original standard-library examples and tests. We checked it with native Go 1.27.3 and also built its demonstration programs for wasip1/wasm. Cross-compilation checks the target build; it does not establish production throughput or certify execution in every app sandbox. The examples use in-memory input, so their behavior is reproducible without a remote server or an account.

## Preserve the bytes that arrive with the final error

The [io.Reader contract](https://pkg.go.dev/io#Reader) permits a call to return useful bytes and an error together, including EOF. A caller must consume the returned bytes before interpreting that error. Our fixture returns the four bytes of tail and io.EOF in the same call. The test also uses smaller destination buffers so the example does not depend on everything fitting in one read.

```go
n, err := r.Read(buf)
if n > 0 {
    consume(buf[:n])
}
if err != nil {
    // Handle EOF or the underlying failure after the bytes.
}
```

A loop that breaks immediately whenever err is non-nil can lose valid final data. Conversely, treating every short read as the end of the message can stop too early. A short read describes the amount delivered by that call, not necessarily the application's document boundary.

Prefer an appropriate helper such as io.ReadAll or io.Copy when its semantics fit. A hand-written loop also needs a policy for a reader that repeatedly makes no progress, destination failures, cancellation and partial side effects. The small snippet above illustrates ordering; it is not a complete production copy implementation. Its purpose is to make a common incorrect assumption visible and testable.

## Distinguish truncating a stream from rejecting oversized input

A reader limited to N bytes can present an artificial end at that boundary. That is useful for exposing a section of input, but it does not by itself prove the original input ended there. The [io.LimitReader documentation](https://pkg.go.dev/io#LimitReader) defines the stopping behavior. The application must decide whether stopping means success, an allowed prefix, or an oversized-message error.

For a small document that must fit entirely in a budget, the lab reads at most one extra byte. Exactly N bytes remain acceptable; N plus one establishes overflow. The helper rejects negative limits and the integer-overflow edge before computing max plus one.

```go
b, err := io.ReadAll(io.LimitReader(r, max+1))
if int64(len(b)) > max {
    return nil, ErrTooLarge
}
if err != nil {
    return nil, err
}
return b, nil
```

This is a deliberately bounded buffering design, not a zero-allocation streaming parser. It uses memory proportional to the configured input limit, plus library overhead. That can be the right tradeoff for small API documents because it establishes the whole envelope before business effects begin. It is inappropriate to give the helper an effectively unlimited budget and describe the result as protected merely because a limit parameter exists.

## Make the boundary test matrix explicit

A useful size test covers an empty payload, a zero-byte allowance, one byte below the limit, exactly the limit, and one byte above it. It also covers an underlying reader failure. Our helper returns no accepted payload when the transport fails or the size exceeds the budget. A different application may deliberately expose partial data, but it must label that result as partial rather than silently accept it as complete.

| Input | Limit | Expected result |
| --- | ---: | --- |
| Empty | 0 | Accepted empty payload |
| One byte | 0 | Oversized input |
| Three bytes | 4 | Complete payload |
| Four bytes | 4 | Complete payload |
| Five bytes | 4 | Oversized input |

The off-by-one case matters because a superficially safe implementation can simply truncate five bytes to four and return success. The lab includes a negative control that changes max plus one to max; the boundary test must then fail. That proves the test can distinguish rejection from truncation.

For an importer, add a business-level assertion: no record is committed after an incomplete document is rejected. A function can return the right error while another component has already persisted half the input. Unit tests for byte handling and integration tests for effects answer different questions, and both boundaries should remain visible in the design.

## Require exactly the document your endpoint promises

A JSON decoder reads the next value. A successful first Decode does not by itself establish that the request contains exactly one value. The [encoding/json decoder reference](https://pkg.go.dev/encoding/json#Decoder) also explains that decoding may buffer beyond the requested value. Reusing the same decoder is therefore important when checking what follows.

The lab first establishes a finite byte envelope, decodes a typed Event, then asks the same decoder for another value. A second successful value is an error for this single-document API. Clean EOF after optional whitespace is accepted; malformed trailing content is rejected.

```go
var extra json.RawMessage
if err := dec.Decode(&extra); err == nil {
    return Event{}, ErrTrailingValue
} else if err != io.EOF {
    return Event{}, err
}
```

Choose the envelope deliberately. A stream of independent JSON values is a valid format when that is the protocol; an endpoint accepting one object has a different contract. Do not apply a single-document check to an intentionally framed multi-message connection and then conclude that streaming is broken. The application's protocol determines whether another value is useful input or a rejected suffix.

For schema evolution and other parser choices, continue with [JSON compatibility](/news/go-json-v2-migration-api-compatibility) and the [input-policy lesson](/learn/stdlib.json-input-policy).

## Separate structural decoding from business validation

Our Event has a required, nonempty identifier. Successfully decoding null or an empty object does not satisfy that requirement. The helper validates the resulting identifier before returning an accepted event. The tests include null, an empty object, an unknown field, malformed input, trailing text and a second complete value.

DisallowUnknownFields is useful for this specific schema policy, but it is not a general strictness certificate. The lab deliberately shows a duplicate identifier field being accepted with the later string value. That example prevents readers from assuming that one decoder option rejects every kind of ambiguity. If duplicate-key rejection is part of the protocol, implement and test that separate policy with an appropriate parser or token-level validation.

The business decision should also consider clients. Rejecting newly introduced fields may be desirable for a small internal command, but it can impede a deliberately forward-compatible event format. A required field may need a separate presence representation when an empty value is meaningful. Those choices belong in an API contract and its compatibility tests.

Keep validation before irreversible effects whenever the operation requires atomic acceptance. If a large import intentionally commits incrementally, give records explicit identifiers, document partial completion, and define retry behavior. A parser cannot retroactively make an already committed batch atomic simply by returning an error at the end.

## Understand token limits before choosing Scanner

Scanner is convenient for bounded records, but its default token allowance is finite. The [bufio reference](https://pkg.go.dev/bufio#Scanner) documents the default 64-KiB buffer limit and notes that delimiters can affect the actual maximum token size. The lab's seventy-KiB line fails under the default configuration and succeeds with an explicitly larger token budget.

```go
scan := bufio.NewScanner(r)
scan.Buffer(make([]byte, 0, 1024), 128*1024)
for scan.Scan() {
    process(scan.Text())
}
if err := scan.Err(); err != nil {
    return err
}
```

Always inspect the final scanning error. Otherwise a parser can report a clean partial import after a large token stops progress. Configure the budget before scanning begins, and choose it from the record contract rather than increasing it until one failing sample happens to pass.

A per-token allowance is not a whole-stream allowance. Ten million individually small records can still represent too much work. Likewise, collecting every scanned record into a slice defeats a claim of bounded retained memory. Pair token size with limits on total bytes, record count, processing concurrency and retained results. The resource boundary is the whole pipeline, not just the convenient loop at its entrance.

## Buffered output has its own completion boundary

Successful input parsing does not establish that output reached its destination. A report generator may write several small rows into a buffered writer and receive no immediate error because the bytes are still held locally. The later flush can fail. The [bufio writer reference](https://pkg.go.dev/bufio#Writer) describes the buffering and flush operations; the feature must decide when it is allowed to report completion.

The lab tests that distinction with an in-memory destination. Before Flush, the destination has no bytes; afterward it contains the expected payload. A separate destination returns an error, and the test requires that Flush expose the failure. This makes a late output failure reproducible without a network service or a full disk.

Keep the completion claim precise. A successful flush through one layer proves that layer accepted the operation under its contract. It does not automatically prove durable storage, remote processing or a committed business transaction. If those stronger guarantees matter, obtain and test the corresponding acknowledgement at that boundary.

For the importer, this creates a useful pair of questions: did the input form a complete accepted message, and did its intended effect complete successfully? Returning success only after the right acknowledgements prevents a byte-processing helper from accidentally defining the business transaction.

## Budget transformations as well as incoming bytes

An input may pass through decompression, decoding, normalization and object construction before the application uses it. A small compressed representation does not establish a small decoded representation. The [gzip reader reference](https://pkg.go.dev/compress/gzip#Reader) defines the decompression layer; the service still needs a budget for the data produced by that layer.

For a compressed upload, distinguish wire-byte limits from decoded-byte limits. Place limits where their meanings are clear, preserve the original error, and explain which budget failed. Add a processing deadline and concurrency limit when the endpoint needs them. A byte ceiling alone does not stop a peer from delivering acceptable bytes indefinitely slowly.

The [HTTP MaxBytesReader API](https://pkg.go.dev/net/http#MaxBytesReader) provides request-body-specific behavior and a size error. Our native tests exercise it with an in-memory request reader and recorder; they do not start a network listener. A real HTTP endpoint should select a status policy and avoid exposing internal diagnostics as its public response.

These controls complement [backpressure and bounded work](/news/go-backpressure-concurrency-limits-queues-deadlines). A service that admits unlimited concurrent bounded requests can still exceed its overall capacity. Describe per-message limits and system-wide admission separately so that operators know which quantity each setting controls.

## Keep cancellation and cleanup attached to the owner

Wrapping a generic reader with a context check between reads does not guarantee that an already blocked Read can be interrupted. The transport or underlying implementation needs an actual cancellation mechanism, deadline or owned close operation. The [context package](https://pkg.go.dev/context) supplies cancellation signals; arbitrary I/O implementations do not automatically observe them.

For a request handler, identify who owns the body and any transformation layers. For a background import, identify who closes the source when the job ends and who waits for workers to exit. An abandoned goroutine holding a reader can preserve both memory and an external resource even after its caller has returned an error.

Avoid deferring cleanup only inside an unbounded outer loop when the resource should end after each record or file. Extract a smaller operation with a clear lifetime if that makes ownership explicit. If cleanup can fail, decide whether it changes the operation's outcome or belongs in a separate diagnostic path.

The [cancel-and-join lesson](/learn/concurrency.cancel-and-join) connects the signal to actual completion. The companion [time and deadline guide](/news/go-time-utc-dst-monotonic-deadlines) explains why a finite timeout and a business calendar deadline are different contracts. Neither a cancellation signal nor a byte limit proves the worker has actually finished.

## Try the failure cases in GopherForge Playground

[Download the complete I/O and time lab](/downloads/go-boundaries-lab-20261029.zip), then open its streamio/main.go. The program is self-contained and uses standard-library packages. In [GopherForge Playground](/playground), download your current source copy before replacing any existing draft, select main.go and paste the demonstration. Keep your own go.mod in the project. Editing the browser draft does not execute Go.

When you want to share an experiment, create a temporary room deliberately. Open that room in a compatible GopherForge app and press the local Run button on the device where execution should happen. Other participants receive device-labelled output for that source revision. Creating a room uploads its source to the relay; simply reading this article does not publish an example or create a room. The [MCP guide](/guide/mcp) explains the capability links and expiry.

Change the payload from four bytes to five while keeping the budget at four. Add a second JSON object, then replace it with whitespace. Increase the scanner's line length past its configured allowance. Before each run, write down the expected accepted value or error. Compare that prediction with the actual output rather than merely checking that the compiler accepted the program.

If Claude or Codex helps, ask it to propose one input mutation and predict the output without running anything. Review its source edit, press Run yourself, and compare the reported revision. This makes the exercise interactive while keeping execution under the local user's control.

## Test the envelope and the effect independently

Run the full suite with go test rather than inferring correctness from a successful demonstration printout. The native tests exercise small destination buffers, exact limits, oversized data, transport failure, JSON suffixes, required values, duplicate-key behavior and Scanner errors. They also check the HTTP size-error type. The published output is an observation from the included source, not a promise that every library error string remains identical across toolchains.

```sh
go test -race -count=50 ./...
go run ./streamio
```

For a real importer, add controlled destination failures and assertions about committed work. Decide whether a failed operation can be retried, whether its record identifiers are idempotent, and how partial completion is reported. Those are application-level contracts outside the small byte-reading helper.

The [buffer-ownership article](/news/go-bytes-buffer-sync-pool-ownership) covers another boundary: whether a result remains valid after a reusable buffer changes. Together, envelope size, framing, ownership and effects give a reviewer a concrete way to assess an input path. The useful question is not simply whether the program streams. It is which boundaries it enforces, which failures it reports, and which useful work remains committed when the stream ends unexpectedly.
