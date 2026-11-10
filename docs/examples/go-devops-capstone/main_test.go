package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

func TestReadinessAndVersionContract(t *testing.T) {
	var ready atomic.Bool
	handler, err := newService("reviewed-a1", &ready)
	if err != nil {
		t.Fatal(err)
	}
	if got := probe(handler, "GET", "/readyz").Code; got != 503 {
		t.Fatal(got)
	}
	if got := probe(handler, "GET", "/livez").Code; got != 204 {
		t.Fatal(got)
	}
	ready.Store(true)
	if got := probe(handler, "GET", "/readyz").Code; got != 204 {
		t.Fatal(got)
	}
	version := probe(handler, "GET", "/version")
	var payload map[string]string
	if err := json.Unmarshal(version.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if version.Code != 200 || payload["revision"] != "reviewed-a1" || version.Header().Get("Content-Type") != "application/json" {
		t.Fatal(version, payload)
	}
	if got := probe(handler, "POST", "/version").Code; got != 405 {
		t.Fatal(got)
	}
	if got := probe(handler, "GET", "/missing").Code; got != 404 {
		t.Fatal(got)
	}
	ready.Store(false)
	if got := probe(handler, "GET", "/readyz").Code; got != 503 {
		t.Fatal(got)
	}
}

type failedWriter struct{}

func (failedWriter) Write([]byte) (int, error) { return 0, errors.New("output unavailable") }
func TestInvalidConfigurationAndOutputFailure(t *testing.T) {
	var ready atomic.Bool
	if _, err := newService(" ", &ready); err == nil {
		t.Fatal("blank revision accepted")
	}
	if _, err := newService("a1", nil); err == nil {
		t.Fatal("missing owner accepted")
	}
	for _, args := range [][]string{{"-typo"}, {"extra"}, {"-serve", "-addr", "0.0.0.0:8080"}} {
		if err := run(args, &bytes.Buffer{}); err == nil {
			t.Fatal("invalid input accepted", args)
		}
	}
	if err := demonstrate(failedWriter{}, "a1"); err == nil {
		t.Fatal("output failure hidden")
	}
	var out bytes.Buffer
	if err := run(nil, &out); err != nil {
		t.Fatal(err)
	}
	if out.String() != "not ready: 503\nready: 204\nversion: 200 {\"revision\":\"local-review\"}\n" {
		t.Fatal(out.String())
	}
}

func TestNativeServerJoinsAfterCancellation(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	var ready atomic.Bool
	handler, err := newService("native-test", &ready)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	finished := make(chan error, 1)
	go func() { finished <- serveOwned(ctx, listener, handler, &ready) }()
	client := &http.Client{Timeout: 2 * time.Second}
	response, err := client.Get("http://" + listener.Addr().String() + "/version")
	if err != nil {
		cancel()
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 200 {
		t.Fatal(response.StatusCode)
	}
	cancel()
	select {
	case err := <-finished:
		if err != nil || ready.Load() {
			t.Fatal(err, ready.Load())
		}
	case <-time.After(4 * time.Second):
		t.Fatal("server owner did not join")
	}
}
