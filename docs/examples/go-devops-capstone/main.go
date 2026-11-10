package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

var buildRevision = "local-review"

func newService(revision string, ready *atomic.Bool) (http.Handler, error) {
	if strings.TrimSpace(revision) == "" || ready == nil {
		return nil, errors.New("revision and readiness owner are required")
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if !ready.Load() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]string{"revision": revision}); err != nil {
			log.Printf("version response: %v", err)
		}
	})
	return mux, nil
}

func probe(handler http.Handler, method, path string) *httptest.ResponseRecorder {
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(method, path, nil))
	return recorder
}

// The default demonstration opens no socket: it also works as a local model.
func demonstrate(out io.Writer, revision string) error {
	var ready atomic.Bool
	handler, err := newService(revision, &ready)
	if err != nil {
		return err
	}
	if _, err := fmt.Fprintln(out, "not ready:", probe(handler, "GET", "/readyz").Code); err != nil {
		return err
	}
	ready.Store(true)
	if _, err := fmt.Fprintln(out, "ready:", probe(handler, "GET", "/readyz").Code); err != nil {
		return err
	}
	version := probe(handler, "GET", "/version")
	_, err = fmt.Fprintf(out, "version: %d %s", version.Code, version.Body.String())
	return err
}

// Native development only. This owner joins its HTTP serving goroutine.
func serveOwned(ctx context.Context, listener net.Listener, handler http.Handler, ready *atomic.Bool) error {
	server := &http.Server{
		Handler: handler, ReadHeaderTimeout: 2 * time.Second,
		IdleTimeout: 30 * time.Second, WriteTimeout: 5 * time.Second,
		MaxHeaderBytes: 16 << 10,
	}
	finished := make(chan error, 1)
	ready.Store(true)
	go func() { finished <- server.Serve(listener) }()
	select {
	case err := <-finished:
		ready.Store(false)
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		ready.Store(false)
		shutdown, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		err := server.Shutdown(shutdown)
		if err != nil {
			_ = server.Close()
		}
		serveErr := <-finished
		if err != nil {
			return err
		}
		if !errors.Is(serveErr, http.ErrServerClosed) {
			return serveErr
		}
		return nil
	}
}

func run(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("service", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	serve := flags.Bool("serve", false, "listen in a native development environment")
	address := flags.String("addr", "127.0.0.1:8080", "explicit loopback address")
	revision := flags.String("revision", buildRevision, "reported build label")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional argument")
	}
	if !*serve {
		return demonstrate(out, *revision)
	}
	var ready atomic.Bool
	handler, err := newService(*revision, &ready)
	if err != nil {
		return err
	}
	host, _, err := net.SplitHostPort(*address)
	ip := net.ParseIP(host)
	if err != nil || ip == nil || !ip.IsLoopback() {
		return errors.New("this lab listens only on an explicit loopback IP")
	}
	listener, err := net.Listen("tcp", *address)
	if err != nil {
		return err
	}
	defer listener.Close()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	return serveOwned(ctx, listener, handler, &ready)
}

func main() {
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
