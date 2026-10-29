## A rollout is part of normal service behavior

A Go service that passes its request tests can still lose work whenever a deployment replaces it. The failure often appears as a small burst of connection resets, abandoned jobs or duplicate writes. Because the burst is brief, teams sometimes accept it as an unavoidable property of Kubernetes. A better starting point is to treat shutdown as an ordinary lifecycle transition with explicit ownership, deadlines and observable outcomes.

Imagine an API that creates export jobs. During a rollout, one replica receives a termination signal while it is accepting requests, writing job records and streaming an existing download. Those activities have different completion conditions. A request may finish when its response is written; a durable job may continue on another worker; a stream may require its own protocol for reconnecting. One call to Server.Shutdown cannot decide the business policy for all of them.

This guide assembles a practical shutdown design, including a minimal HTTP example and a test plan. The time budgets are examples for reasoning, not claims about network propagation or a universal Kubernetes configuration. Start with [HTTP service lifecycle](/learn/services.http-lifecycle) and [probes and shutdown](/learn/operations.probes-and-shutdown) for the underlying APIs. The important outcome is a service that can explain which work it accepts, which work it finishes, and which work it deliberately abandons when its deadline expires.

## Separate admission, draining, cancellation and completion

These four actions are related but different. Admission determines whether new work may enter. Draining allows already accepted work to finish. Cancellation asks selected work to stop. Completion establishes that the owner has actually observed its children exit. A service that cancels everything immediately may not drain anything. A service that merely requests cancellation may exit before cleanup happens.

Write a resource table before writing lifecycle code. For each HTTP listener, queue consumer, scheduler, database pool, outbound transport and long-lived session, identify the owner, the stop-accepting action, the completion signal and the deadline. Shared dependencies must remain available until their last legitimate user has finished.

For the fictional export service, the HTTP listener stops new requests, a queue consumer stops fetching new jobs, and an active export either completes within a defined allowance or records recoverable progress. The database stays available while accepted handlers and workers persist their final state. Closing the pool first turns an orderly exit into a cascade of artificial database errors.

This ordering is an application design recommendation, not a guarantee supplied by the platform. A request may have already crossed a proxy while a readiness update is propagating. An unexpected process crash provides no graceful window at all. Correctness must therefore also survive interruption, using durable state and idempotent operations where the business action requires them.

## The Kubernetes grace period is a shared budget

The Kubernetes [Pod lifecycle documentation](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/) describes a termination grace period, termination signals and eventual forced termination. A configured preStop hook consumes time within that lifecycle; it is not a free extra interval added before the application's allowance begins.

Suppose the chosen Pod grace period is forty seconds. A team might budget five seconds for measured routing preparation, twenty-five for request draining, five for worker completion and five for cleanup and scheduling uncertainty. The sum matters. If each component independently allocates the full forty seconds, the composed lifecycle cannot fit inside forty seconds.

Use one absolute shutdown deadline when coordinating several components. Derive child deadlines from the remaining time or explicitly reserve time for later cleanup. A chain of fresh thirty-second timeouts is not a thirty-second shutdown. It is potentially several minutes of shutdown that the orchestrator may interrupt much earlier.

Do not build correctness around the grace period always being available. Node failure, resource exhaustion and an administrative force deletion can bypass the intended path. A grace period improves the probability of an orderly transition; it is not a transactional boundary. Record unfinished durable work so another owner can recover it, and test the recovery path separately from the graceful path.

## Readiness changes routing intent, not reality instantly

Readiness answers whether a replica should receive normal traffic. Liveness answers whether restarting the process may help. Startup probes protect slow initialization from premature liveness failures. Their roles should remain distinct; a temporary database outage should not automatically cause every otherwise healthy API process to restart simultaneously.

The official [probe guide](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) explains these mechanics. For shutdown, make readiness reflect the transition toward draining. Keep liveness meaningful while the process is still executing its shutdown responsibilities, rather than declaring it dead simply because it has stopped accepting new work.

EndpointSlice updates and data-plane behavior are separate layers. Kubernetes exposes readiness and termination information, but your ingress, load balancer, service mesh and existing connections determine how traffic actually reaches a process. The [EndpointSlice reference](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/) is useful for understanding those conditions; it does not establish a fixed propagation delay for every cluster.

Measure that delay in the environment you operate. If a preparation interval is needed, include it inside the total budget and explain what evidence supports its duration. An unexplained sleep copied from another team's YAML can spend most of a small grace period without establishing that any relevant routing component has stopped sending traffic.

## Use a fresh context for the drain operation

A common shutdown bug passes the already-cancelled signal context to Server.Shutdown. The application receives a termination signal, cancels its lifecycle context, and immediately tells Shutdown that its own deadline is over. The resulting forced closure then looks like a failure of graceful shutdown rather than a context-ownership mistake.

Use the signal context to trigger the transition. Create a separate bounded context for the drain. Keep request contexts alive while they are intentionally allowed to finish, unless your policy explicitly cancels them. If Server.BaseContext is derived directly from the signal context, cancellation may reach every handler at the first signal, defeating that policy.

Signal handling also needs an owner. The standard [os/signal reference](https://pkg.go.dev/os/signal#NotifyContext) describes NotifyContext and its stop function. Releasing the notification registration after the first signal can restore ordinary behavior for a subsequent interrupt when the process otherwise has the default disposition. Verify the actual process tree and container entrypoint instead of assuming a shell forwards signals correctly.

Keep cleanup functions bounded and error-aware. Log a drain timeout as an incomplete shutdown, not as a successful deployment event. If force-closing ordinary HTTP connections is the chosen fallback, make that explicit and ensure callers have an idempotent recovery path for ambiguous writes.

## A minimal HTTP owner that waits for shutdown

The following function owns one listener and one HTTP server. The caller owns signal registration and supplies a context cancelled on the first termination signal. A separate readiness handler can read the same atomic flag. This example intentionally excludes queue workers, WebSockets, routing preparation and database cleanup; those require explicit additional owners.

```go
func serve(ctx context.Context, ln net.Listener,
    handler http.Handler, ready *atomic.Bool) error {
    srv := &http.Server{
        Handler: handler,
        ReadHeaderTimeout: 5 * time.Second,
        IdleTimeout: 60 * time.Second,
    }
    stopped := make(chan error, 1)
    ready.Store(true)
    go func() { stopped <- srv.Serve(ln) }()

    select {
    case err := <-stopped:
        ready.Store(false)
        if errors.Is(err, http.ErrServerClosed) { return nil }
        return err
    case <-ctx.Done():
    }

    ready.Store(false)
    drain, cancel := context.WithTimeout(context.Background(), 25*time.Second)
    defer cancel()
    shutdownErr := srv.Shutdown(drain)
    if shutdownErr != nil { _ = srv.Close() }
    serveErr := <-stopped
    if errors.Is(serveErr, http.ErrServerClosed) { serveErr = nil }
    return errors.Join(shutdownErr, serveErr)
}
```

The buffered result channel prevents the serving goroutine from being stranded if the lifecycle owner is temporarily elsewhere. The owner waits for Shutdown itself, not merely for Serve to return. This distinction matters because the serving loop can stop before active handlers have completed. Read the [Server.Shutdown contract](https://pkg.go.dev/net/http#Server.Shutdown) together with the code rather than treating the function name as a complete lifecycle specification.

The twenty-five-second timeout is deliberately visible. Production code should make its relationship to the external grace budget configurable and documented. If Shutdown times out, Close does not prove that arbitrary handler goroutines or their side effects have finished; cooperative cancellation and durable outcomes still need separate design.

## Join workers before closing their dependencies

Background work needs a completion signal just as request-serving work does. For a queue consumer, distinguish stopping new fetches from cancelling an already running job. For a periodic scheduler, stop creating new tasks before waiting for the tasks it already created. A WaitGroup can count completions, but it does not define cancellation, persistence or retry policy.

A useful lifecycle interface might expose StopAccepting, Drain and Close, provided those names have documented semantics and do not hide ownership. Simpler services can use explicit functions and channels instead. The abstraction is worthwhile only when it makes the real sequence easier to inspect.

Cancellation should reach every blocking operation a worker owns: queue reads, database calls, outbound requests and sends to result channels. A goroutine stuck sending a final status to an abandoned receiver can prevent completion even though its main job has stopped. If a channel has multiple producers, define who closes it after all producers finish; closing it from an arbitrary worker creates a different shutdown failure.

Use [cancel and join](/learn/concurrency.cancel-and-join) as a review checklist. The most useful question is often simple: after requesting cancellation, which line establishes that this goroutine is gone? If the answer is an arbitrary sleep or the process exit itself, the lifecycle is relying on timing rather than completion evidence.

## Long-lived protocols need their own drain strategy

Ordinary HTTP request draining is not the same as draining a WebSocket, a hijacked connection, a long-running stream or an independent RPC server. Each protocol can have a different notion of a session, accepted work and reconnect safety. Inventory these paths explicitly, including endpoints that are rarely exercised during a deployment.

For a subscription service, a reasonable policy might stop new subscriptions, notify existing clients of an upcoming disconnect, allow a bounded period to acknowledge or checkpoint, then close remaining sessions. The exact mechanism belongs to that protocol. A list of active sessions must itself have a concurrency-safe owner and a completion signal; a notification callback alone is not proof that all sessions have exited.

For streaming downloads, consider whether clients can resume safely and whether keeping the process alive for an arbitrarily large transfer is acceptable. For durable jobs, distinguish an in-process stream from the durable job state so that a new replica can recover the latter. Clients should not have to infer completion from a connection closing at an unknown point.

Document what the shutdown deadline means for these protocols. If an operation exceeds the allowed window, define the recovery path before relying on a retry. A forced disconnect after a committed write can produce the same ambiguity discussed in our [SQL pool and transaction guide](/news/go-database-sql-pool-timeouts-transactions).

## Make the deployment configuration match the code

A service whose internal drain limit is twenty-five seconds should not be deployed with a ten-second external grace period. Conversely, a very large grace period can slow recovery when workers never finish. Choose the configuration from measured work duration, routing behavior and a clear maximum recovery delay.

```yaml
# Pod-spec excerpt; image, ports and resources belong in the complete manifest.
terminationGracePeriodSeconds: 40
containers:
  - name: api
    image: registry.example.com/api:verified-release
    readinessProbe:
      httpGet:
        path: /readyz
        port: 8080
      periodSeconds: 2
    livenessProbe:
      httpGet:
        path: /livez
        port: 8080
      periodSeconds: 10
```

This excerpt deliberately omits a preStop hook. Add one only when it performs an understood preparation step and fits inside the shared budget. The [container lifecycle hook documentation](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) describes the mechanism. Ensure the command or HTTP endpoint actually exists in the image and that administrative drain endpoints are not exposed to untrusted callers.

Also review rolling-update surge and unavailable-replica settings against dependency capacity. Draining old replicas and starting new ones can temporarily increase total database connections. A rollout that preserves HTTP availability but exhausts the shared database budget has moved the outage, not removed it. Tie these settings to the capacity worksheet rather than reviewing application code and manifests independently.

## Test shutdown with observable barriers

A useful local test starts a real loopback listener, admits a handler that announces it has started, then blocks that handler on a release channel. Cancel the lifecycle context and assert that the lifecycle owner has not returned while the accepted handler is still deliberately blocked. Release it, read the expected response, and confirm that shutdown returns successfully.

A second test deliberately keeps work beyond a short drain deadline and verifies the documented fallback and error. A third checks a startup failure so that the process does not wait forever for a signal after its listener has already failed. Use channels to establish ordering; do not rely on sleeping long enough for a goroutine to probably start.

These tests validate the local HTTP owner. They do not establish ingress propagation time, Pod hook behavior or database recovery. Exercise those separately in a disposable cluster: keep a bounded stream of requests running while performing a rollout, track request identifiers, and compare accepted work with durable outcomes. Include old and new versions if their protocols or schemas differ.

Read the [deterministic concurrency testing guide](/news/go-concurrency-tests-synctest-without-sleeps) for the distinction between coordination evidence and elapsed time. A green local test is valuable precisely because its claim is narrow and reproducible.

## Observe transitions and define the forced-exit outcome

Record when shutdown begins, when admission stops, when HTTP draining completes, when workers exit and when resources close. Count active work at each boundary. Include a bounded reason such as deployment, operator signal or startup failure. Avoid turning arbitrary request identifiers into metric labels.

The most useful alert is not simply that a Pod terminated. Termination is expected during a rollout. Look for repeated drain deadlines, unfinished durable jobs, client-visible errors and a mismatch between admitted work and acknowledged outcomes. A histogram of shutdown duration helps explain whether a new release changed the lifecycle, but it should be interpreted alongside those outcome measurements.

Finally, practice interruption without a graceful window. A durable job system should recover from a process disappearing, not just from a politely cancelled context. A client retry should not create duplicate business operations because the last response was lost. Graceful shutdown reduces disruption; recovery design handles the failures that do not ask permission.

Continue with [Kubernetes rollout inspection](/learn/operations.kubernetes-rollout), [bounded work](/learn/concurrency.bounded-work) and [service shutdown interview preparation](/interview/http.shutdown). A strong service has a lifecycle that can be described in order, exercised under a deadline and verified through outcomes. That is a more durable result than a shutdown function copied into main without a resource owner.

[Download the original compilable examples and tests](/downloads/go-engineering-examples-20261029.zip). The ZIP includes imports, the local regression suite and a README explaining exactly what was verified.
