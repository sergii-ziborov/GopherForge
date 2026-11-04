## A request ID is not a distributed trace

A handler logs one request ID, a database wrapper logs another identifier, and a worker reports that a job failed later. Each component has records, yet the team cannot follow one operation across the boundaries. Adding more log lines may increase volume without restoring the missing relationships. A distributed trace is useful because it represents related work explicitly, including where one stage waits for another and where independent work begins.

This guide belongs to the **3 November 2026 archive edition** and was researched and first published on **4 November 2026**. Its original lab uses OpenTelemetry Go v1.47.0 with an in-memory span recorder under Go 1.27.3. The tests verify propagation and parent relationships without installing a collector or sending telemetry to a remote service. The article describes instrumentation choices for your applications; it does not add telemetry to GopherForge.

Begin with one operation you cannot currently diagnose. Identify its inbound boundary, the work it calls synchronously and any job that outlives the request. Then decide which relationships a trace must preserve. A clear boundary map is more valuable than instrumenting every function before anyone can explain what the resulting spans mean or which data they are allowed to contain.

## Trace context carries correlation, not authorization

[W3C Trace Context](https://www.w3.org/TR/trace-context/) standardizes headers that communicate tracing identifiers and related metadata between services. An inbound trace identifier can help join observations, but it is not proof of identity, permission or trustworthy origin. Do not use it as an authorization token or as the sole key for a security-sensitive operation.

At a public boundary, treat incoming tracing headers as external input. Let a supported propagator parse the format and decide how invalid context is handled. Also decide whether your trust model permits continuing an external trace or requires a new local tracing boundary. That policy should be distinct from authentication and from the application's own durable operation identifiers.

A useful review exercise is to remove the word tracing from the design temporarily. Would accepting this caller-supplied identifier let someone read another user's data, select an internal tenant or bypass a limit? If so, correlation has accidentally become authority. Keep those decisions in explicit application fields with their own validation. Tracing should help explain an operation after it has been admitted under the correct rules, not silently change which operation a caller is allowed to perform.

## Extract, start, propagate and record

Use four stages. Extract accepted context at the incoming boundary. Start a span representing the work your component owns. Propagate the current context when calling another component. Record approved outcomes and attributes that help explain that work. This sequence is small enough to inspect in a test and general enough to apply to Gin, ordinary HTTP handlers, RPC clients and queue consumers.

The [Go propagation package](https://pkg.go.dev/go.opentelemetry.io/otel/propagation) supplies carrier abstractions and the TraceContext propagator. A carrier represents where the metadata travels, such as HTTP headers. Creating a context in Go does not automatically write it into a network request; injection and extraction are the bridge between in-process state and the transport.

Document who owns each boundary. A server middleware may already create the inbound server span, while an instrumented HTTP client may already create an outbound span and inject headers. Adding another layer without checking the existing instrumentation can duplicate spans and confuse the picture. The right result is not the largest number of spans. It is a coherent account of useful work, with enough detail to distinguish execution from waiting and with a clear explanation of which instrumentation produced each observation.

## Separate API use from SDK configuration

Application libraries can use tracing interfaces without owning the process-wide export configuration. The executable normally chooses the SDK provider, resource identity, processing and export behavior. This separation lets a reusable package describe its work while the application decides where observations go and how much information is retained.

The [OpenTelemetry Go instrumentation guide](https://opentelemetry.io/docs/languages/go/instrumentation/) explains provider and tracer setup. A common failure is adding span calls while leaving the executable with a provider configuration that records nothing useful. Another is letting each library independently configure global export behavior. Inspect initialization and ownership before concluding that missing spans prove propagation is broken.

Our lab passes a provider explicitly to the function under test. That makes the test self-contained and prevents it from changing global instrumentation for unrelated packages. Production code may choose a process-level provider, but it still needs a single intentional lifecycle owner. Record the selected SDK version and exporter configuration with the deployment. A working local console example is evidence that the code can create observations, not evidence that a production collector received them or that every replica uses the same configuration.

## Preserve the active context across synchronous calls

Starting a child operation from an unrelated background context breaks its relationship to the request. Passing a context through a function signature is useful only if the implementation actually uses that context when starting the child work and invoking the downstream operation. A context stored in a struct but ignored at the boundary is not propagation.

The lab extracts a fixed synthetic parent, starts a server span and then starts an outbound client span from that server context. It injects the client span's context into a fresh carrier. The test checks that the server retains the remote parent, the client retains the server parent, and the outgoing carrier identifies the client span within the same trace. These assertions target the relationships directly rather than checking only that two spans exist.

This is especially useful when reviewing helper wrappers. A wrapper that creates a new context for convenience can retain cancellation behavior differently from correlation behavior, or lose both. Inspect the complete call path. The [deadline guide](/news/go-context-deadline-exceeded-timeout-diagnosis) provides the complementary question: does cancellation reach the operation that can stop? Correlation and cancellation both travel through context, but they remain different contracts that deserve separate assertions.

## Durable jobs need a lifetime decision

A job can outlive the HTTP request that created it. Pretending that all of its work remains inside one continuously open request span can misrepresent ownership and duration. The producer should record the handoff, and the consumer should establish the job-processing observation according to the queue's lifecycle and your tracing policy. A link can express a relationship where a single synchronous parent-child story would be misleading.

Choose what survives in the message envelope. A durable application operation ID, a tracing carrier and business payload fields serve different purposes. Define how retries, delayed delivery and multiple attempts appear. One job attempt may fail while a later attempt succeeds; hiding both inside an undifferentiated span makes it harder to understand actual processing and acknowledgment behavior.

Also distinguish request cancellation from job cancellation. Once a durable enqueue succeeds, a disconnected browser does not necessarily cancel the job. Conversely, a job should not run forever merely because it was detached from the original request context. Give the worker its own owner, finite execution policy and shutdown behavior. Our illustration is conceptual; the supplied lab verifies synchronous propagation only. Extending it to a queue requires tests for message carriers, retries, acknowledgment and the durable handoff you actually implement.

## Keep attributes useful, bounded and approved

A stable route template is usually more useful for grouping requests than a raw URL containing identifiers. An operation name such as a fixed catalog lookup can remain meaningful across calls without creating a new label value for every resource. Record approved outcome classes and bounded counts, then use controlled correlation when investigating a specific operation.

Full request bodies, database documents, authorization headers and arbitrary query strings should not become default span attributes. Apart from data-handling concerns, unbounded values and cardinality can make telemetry expensive and difficult to query. Define an attribute schema with named owners rather than relying on every developer to guess which fields are appropriate at each call site.

[OpenTelemetry's baggage guidance](https://opentelemetry.io/docs/concepts/signals/baggage/) explains that baggage can propagate to downstream resources. Baggage is not simply a private map attached to the current function. Our fixture deliberately uses only TraceContext propagation and verifies that a synthetic baggage field is absent from the outgoing carrier. That narrow test establishes the fixture's selected behavior; it does not prove that other middleware, another propagator or a collector transformation follows the same policy. Review the assembled pipeline and its actual destinations.

## Record failures without turning raw errors into payload dumps

An operation can fail without the trace making that failure visible in the way a query expects. The instrumentation documentation distinguishes recording an error event from setting a span status: `RecordError` does not automatically set error status. Choose the outcome semantics for the operation and record them intentionally before ending the span.

Also inspect the error value being recorded. A raw error string may contain a connection string, query value or document fragment. A stable approved classification can be useful without forwarding every internal detail. Preserve enough local diagnostic context under the application's data policy to investigate the failure, but avoid making a tracing wrapper a universal serialization mechanism for arbitrary error objects.

Tests should distinguish a business-level not-found result, caller cancellation, dependency failure and an internal defect where those outcomes matter to the operation. Do not label every non-nil error identically merely because a helper accepts an error argument. The [structured logging guide](/news/go-slog-structured-logging-context-redaction) develops similar field-selection rules for events. A consistent classification across logs and traces is valuable, provided the classification describes the operation rather than hiding every failure behind one generic success-shaped record.

## Sampling changes what absence can tell you

A trace that is not present in a backend may have been unsampled, dropped under pressure, rejected by an exporter or sent somewhere other than the environment you are viewing. Missing observations do not automatically prove that the request never ran. Sampling and delivery behavior need to be part of the operational explanation.

Choose a policy that matches the diagnostic questions and resource budget. The lab uses an explicit test configuration so its synthetic spans are recorded predictably. That is not a recommendation to record every production request. A high-volume service needs to evaluate sampling, attribute limits, queue capacity and collector behavior using its real workload and failure requirements.

Keep service identity and deployment version stable enough to distinguish replicas and releases. When comparing an incident with a previous version, verify that the instrumentation and sampling configuration are comparable. An apparent reduction in slow traces might result from a changed recording policy rather than faster operations. The [SDK trace documentation](https://pkg.go.dev/go.opentelemetry.io/otel/sdk/trace) is the implementation reference; the engineering task is to connect those settings to a finite operational budget and an interpretation that remains valid when some observations are missing.

## Shutdown is part of the telemetry lifecycle

Buffered observations can remain in process when the application begins stopping. Give the tracing provider and exporter a lifecycle owner that participates in graceful shutdown. Stop admitting work according to the application policy, let owned operations finish within their budget and allow a bounded opportunity to flush and release telemetry resources.

Do not reuse an already canceled request context as the only cleanup budget for the process-wide provider. Create an intentional shutdown budget when that cleanup stage begins. Record whether flushing or shutdown failed, and avoid blocking indefinitely merely to preserve a final observation. Telemetry should help operate the service rather than become an unbounded dependency during termination.

The SDK documents provider and processor shutdown behavior. Our in-memory test cleans up its provider and makes no claim about a remote collector's delivery guarantees. For an actual deployment, test collector unavailability, a full exporter queue and process termination during active requests. The [Go shutdown guide](/news/go-http-graceful-shutdown-kubernetes) connects that work to HTTP, background workers and orchestrator grace periods. The useful result is a known lifecycle policy, not a promise that every final span always reaches its destination.

## Assert the trace graph directly in tests

[Download the engineering lab](/downloads/go-engineering-lab-20261104.zip) and run `go test -race ./tracelab`. It uses the official SDK's [in-memory test recorder](https://pkg.go.dev/go.opentelemetry.io/otel/sdk/trace/tracetest). One test checks the remote parent, server span, client span and outgoing carrier. Another supplies malformed parent metadata and verifies that a fresh valid trace begins instead of accepting the invalid parent.

These tests are more informative than checking only that a logging function was called. A function can record spans while assigning the wrong parent, injecting an old span ID or losing the trace at a helper boundary. The graph assertions expose those mistakes without requiring a dashboard, an account or a network collector.

Keep integration tests for the assembled application as a separate layer. Confirm that the real Gin or HTTP middleware, client instrumentation and exporter produce the expected graph under your selected configuration. Verify both a successful request and a canceled or failed one. An in-memory fixture proves SDK interactions for its inputs; it cannot establish remote ingestion, retention, access control or production sampling. Naming that boundary keeps the example useful when it is adapted into a real service.

## Introduce tracing around one unanswered question

Choose a request that currently takes too long or fails without a clear stage. Add stable observations around its meaningful boundaries, then reproduce the problem with synthetic or approved data. Compare execution time, waiting and outcome classification. Avoid starting with a requirement to instrument every helper in the repository; excessive detail can obscure the relationship you were trying to understand.

For interview preparation, explain why creating a context is not the same as injecting it into a carrier, why a trace ID is not authorization, and why a durable job may need a different lifetime model. The [context-contract lesson](/learn/clean-production.context-contracts) and [distributed-service guide](/news/dapr-1-19-rc4-go-service-boundaries) make useful next steps. A compatible fixture can be discussed through [Playground](/playground) and its [MCP workflow](/guide/mcp) using the observed output.

Finish by documenting the span owner, attribute policy, propagation format, sampling configuration and shutdown budget. Another engineer should be able to explain an observed graph and identify what it cannot prove. That is a much stronger foundation than a colorful trace screenshot whose boundaries, payloads and missing spans nobody can account for.
