package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"strings"
	"time"
)

// Secret protects this typed representation, not arbitrary copies of its text.
type Secret string

func (Secret) LogValue() slog.Value { return slog.StringValue("[REDACTED]") }

func replace(_ []string, a slog.Attr) slog.Attr {
	switch strings.ToLower(a.Key) {
	case "authorization", "password", "token":
		return slog.String(a.Key, "[REDACTED]")
	}
	return a
}
func NewLogger(w io.Writer, level slog.Leveler, deterministic bool) *slog.Logger {
	return slog.New(slog.NewJSONHandler(w, &slog.HandlerOptions{
		Level: level,
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			if deterministic && len(groups) == 0 && a.Key == slog.TimeKey {
				return slog.Attr{}
			}
			return replace(groups, a)
		},
	}))
}

// The caller supplies a trusted route template and synthetic request ID.
// Never substitute a raw URL, path, query, header or capability token here.
func RequestLogger(base *slog.Logger, requestID string) *slog.Logger {
	return base.With(slog.String("service", "catalog"), slog.String("request_id", requestID)).WithGroup("request")
}
func ErrorClass(err error) string {
	switch {
	case err == nil:
		return "ok"
	case errors.Is(err, context.DeadlineExceeded):
		return "deadline"
	case errors.Is(err, context.Canceled):
		return "canceled"
	default:
		return "internal"
	}
}
func Complete(ctx context.Context, l *slog.Logger, route string, status int, elapsed time.Duration, err error) {
	level := slog.LevelInfo
	if status >= 500 {
		level = slog.LevelError
	}
	l.LogAttrs(ctx, level, "request.complete", slog.String("route", route), slog.Int("status", status), slog.Int64("duration_ms", elapsed.Milliseconds()), slog.String("outcome", ErrorClass(err)))
}
func DebugSummary(ctx context.Context, l *slog.Logger, build func() string) {
	if l.Enabled(ctx, slog.LevelDebug) {
		l.DebugContext(ctx, "diagnostic.summary", "summary", build())
	}
}

var errSink = errors.New("synthetic sink failure")

type brokenWriter struct{ calls int }

func (w *brokenWriter) Write([]byte) (int, error) { w.calls++; return 0, errSink }
func main() {
	ctx := context.Background()
	l := NewLogger(os.Stdout, slog.LevelInfo, true)
	Complete(ctx, RequestLogger(l, "demo-001"), "/items/{id}", 200, 120*time.Millisecond, nil)
	l.Info("credential.example", "credential", Secret("synthetic-secret"), "token", "synthetic-token")
	count := 0
	build := func() string { count++; return "expensive synthetic summary" }
	l.Debug("eager.example", "summary", build())
	DebugSummary(ctx, l, build)
	fmt.Printf("summary builds with eager then guarded disabled debug: %d\n", count)
	sink := &brokenWriter{}
	h := slog.NewJSONHandler(sink, nil)
	slog.New(h).Info("logger ignores handler error")
	err := h.Handle(ctx, slog.NewRecord(time.Time{}, slog.LevelInfo, "direct handler returns error", 0))
	fmt.Printf("writer calls: %d; direct handler error: %v\n", sink.calls, err)
}
