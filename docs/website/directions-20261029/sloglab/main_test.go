package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"
)

func record(t *testing.T, b *bytes.Buffer) map[string]any {
	t.Helper()
	var got map[string]any
	if err := json.Unmarshal(b.Bytes(), &got); err != nil {
		t.Fatal(err, b.String())
	}
	return got
}
func TestRequestSchemaAndCancellation(t *testing.T) {
	var b bytes.Buffer
	l := RequestLogger(NewLogger(&b, slog.LevelInfo, true), "synthetic-001")
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	Complete(ctx, l, "/items/{id}", 503, 12*time.Millisecond, context.DeadlineExceeded)
	got := record(t, &b)
	if got["level"] != "ERROR" || got["request_id"] != "synthetic-001" || got["service"] != "catalog" {
		t.Fatal(got)
	}
	request, ok := got["request"].(map[string]any)
	if !ok {
		t.Fatal("missing group", got)
	}
	if request["route"] != "/items/{id}" || request["status"] != float64(503) || request["duration_ms"] != float64(12) || request["outcome"] != "deadline" {
		t.Fatal(request)
	}
	if len(got) != 5 || len(request) != 4 {
		t.Fatal("unexpected schema", got)
	}
}
func TestRedactionAndNarrowBoundary(t *testing.T) {
	var b bytes.Buffer
	l := NewLogger(&b, slog.LevelInfo, true)
	l.WithGroup("auth").Info("synthetic", "credential", Secret("private-example"), "Authorization", "private-bearer")
	if strings.Contains(b.String(), "private-") {
		t.Fatal("secret leaked", b.String())
	}
	auth := record(t, &b)["auth"].(map[string]any)
	if auth["credential"] != "[REDACTED]" || auth["Authorization"] != "[REDACTED]" {
		t.Fatal(auth)
	}
	b.Reset()
	l.Info("converted", "credential", string(Secret("synthetic-plaintext")))
	if record(t, &b)["credential"] != "synthetic-plaintext" {
		t.Fatal("conversion demonstration changed")
	}
}
func TestLevelsAndExpensiveArguments(t *testing.T) {
	var b bytes.Buffer
	var level slog.LevelVar
	level.Set(slog.LevelInfo)
	l := NewLogger(&b, &level, true)
	count := 0
	build := func() string { count++; return "summary" }
	DebugSummary(context.Background(), l, build)
	if count != 0 || b.Len() != 0 {
		t.Fatal("disabled guard performed work")
	}
	l.Debug("eager", "summary", build())
	if count != 1 || b.Len() != 0 {
		t.Fatal(count, b.String())
	}
	level.Set(slog.LevelDebug)
	DebugSummary(context.Background(), l, build)
	if count != 2 || record(t, &b)["level"] != "DEBUG" {
		t.Fatal(count, b.String())
	}
}
func TestWriterFailureBoundary(t *testing.T) {
	w := &brokenWriter{}
	h := slog.NewJSONHandler(w, nil)
	slog.New(h).Info("synthetic")
	if w.calls != 1 {
		t.Fatal(w.calls)
	}
	err := h.Handle(context.Background(), slog.NewRecord(time.Time{}, slog.LevelInfo, "synthetic", 0))
	if !errors.Is(err, errSink) || w.calls != 2 {
		t.Fatal(err, w.calls)
	}
}
func TestErrorClassificationDoesNotCopyMessage(t *testing.T) {
	var b bytes.Buffer
	Complete(context.Background(), NewLogger(&b, slog.LevelInfo, true), "/fixed", 500, time.Millisecond, errors.New("private-marker"))
	if strings.Contains(b.String(), "private-marker") {
		t.Fatal("message copied")
	}
	if record(t, &b)["outcome"] != "internal" {
		t.Fatal(b.String())
	}
}
func TestConcurrentRecordsAndChildIsolation(t *testing.T) {
	var b bytes.Buffer
	root := NewLogger(&b, slog.LevelInfo, true)
	child := root.WithGroup("child")
	var wg sync.WaitGroup
	for i := 0; i < 16; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); child.Info("event", "value", 1) }()
	}
	wg.Wait()
	root.Info("root", "value", 2)
	dec := json.NewDecoder(&b)
	n := 0
	for {
		var got map[string]any
		err := dec.Decode(&got)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		if n < 16 {
			if _, ok := got["child"]; !ok {
				t.Fatal(got)
			}
		} else {
			if _, ok := got["child"]; ok {
				t.Fatal("child mutated root")
			}
		}
		n++
	}
	if n != 17 {
		t.Fatal(n)
	}
}
