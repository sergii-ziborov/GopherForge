# Local TLS verification controls

Original example for the [eMudhra incident-response article](https://gopherforge.app/news/go-emudhra-urgent-tls-incident-response).

```sh
go test -race ./...
```

The test creates a loopback TLS server and checks trusted, unknown-authority and wrong-hostname cases. It does not contact external services, reproduce the compromised intermediates, or certify that a Go security patch is present. Adapt these controls to the application's real client constructor. Native Go/network access is required; this is not a guest-WASI networking example.
