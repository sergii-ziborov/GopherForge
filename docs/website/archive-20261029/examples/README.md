# Original Go engineering examples

Companion code for the GopherForge archive editions of 24, 25 and 28 October 2026, published on 29 October. Requires Go 1.25 or later; verified with native Go 1.27.3.

Run from this directory:

```sh
go version
go test -race -count=100 -timeout=30s ./...
```

The article snippets are unchanged apart from gofmt and imports. `sqlpool_test.go` uses a deliberately synthetic database driver: it checks pool waiting, row ownership and transaction completion, not PostgreSQL query semantics or server-side cancellation. `shutdown_test.go` binds only a local loopback listener and checks admitted-handler draining and startup failure. `synctest_test.go` checks virtual-time boundaries and cancellation. The separate QA receipt records three negative-control mutations; the faulty variants are not included.

This is not a Kubernetes deployment test, load benchmark, native-app sandbox certification, or proof of race freedom in all executions. Real driver, database, proxy and cluster integration require separate environments and appropriate budgets.
