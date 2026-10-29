package examples

import (
	"context"
	"io"
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

type observedListener struct {
	net.Listener
	closed chan struct{}
}

func (l *observedListener) Close() error { err := l.Listener.Close(); close(l.closed); return err }
func TestShutdownWaitsForAdmittedHandler(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	wrapped := &observedListener{Listener: ln, closed: make(chan struct{})}
	entered, release := make(chan struct{}), make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(entered)
		<-release
		_, _ = io.WriteString(w, "finished")
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var ready atomic.Bool
	result := make(chan error, 1)
	go func() { result <- serve(ctx, wrapped, handler, &ready) }()
	clientResult := make(chan error, 1)
	go func() {
		c := &http.Client{Timeout: 5 * time.Second}
		r, e := c.Get("http://" + ln.Addr().String())
		if e != nil {
			clientResult <- e
			return
		}
		defer r.Body.Close()
		b, e := io.ReadAll(r.Body)
		if e == nil && string(b) != "finished" {
			e = io.ErrUnexpectedEOF
		}
		clientResult <- e
	}()
	<-entered
	cancel()
	<-wrapped.closed // Shutdown has actually closed admission.
	if ready.Load() {
		t.Fatal("still ready after listener closed")
	}
	select {
	case e := <-result:
		t.Fatalf("returned before handler finished: %v", e)
	default:
	}
	close(release)
	if e := <-clientResult; e != nil {
		t.Fatal(e)
	}
	if e := <-result; e != nil {
		t.Fatal(e)
	}
}
func TestServeStartupFailure(t *testing.T) {
	ln, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	_ = ln.Close()
	var ready atomic.Bool
	e = serve(context.Background(), ln, http.NotFoundHandler(), &ready)
	if e == nil {
		t.Fatal("startup failure hidden")
	}
	if ready.Load() {
		t.Fatal("failed server ready")
	}
}
