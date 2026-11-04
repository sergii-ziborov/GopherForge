package cachelab

import (
	"context"
	"errors"
	"golang.org/x/sync/singleflight"
	"sync/atomic"
	"testing"
	"time"
)

func TestDuplicateCallsShareOneLoader(t *testing.T) {
	l, _ := New(time.Second)
	release := make(chan struct{})
	var calls atomic.Int32
	var results []<-chan singleflight.Result
	for i := 0; i < 20; i++ {
		results = append(results, l.Start("same", func(context.Context) (string, error) { calls.Add(1); <-release; return "value", nil }))
	}
	close(release)
	for _, ch := range results {
		v, e := Await(context.Background(), ch)
		if e != nil || v != "value" {
			t.Fatal(v, e)
		}
	}
	if calls.Load() != 1 {
		t.Fatal(calls.Load())
	}
}
func TestCanceledWaiterDoesNotCancelSharedWork(t *testing.T) {
	l, _ := New(time.Second)
	release := make(chan struct{})
	fn := func(ctx context.Context) (string, error) {
		select {
		case <-release:
			return "ok", nil
		case <-ctx.Done():
			return "", ctx.Err()
		}
	}
	a := l.Start("key", fn)
	b := l.Start("key", fn)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, e := Await(ctx, b); !errors.Is(e, context.Canceled) {
		t.Fatal(e)
	}
	close(release)
	if v, e := Await(context.Background(), a); v != "ok" || e != nil {
		t.Fatal(v, e)
	}
}
func TestLoaderOwnBudgetAndInvalidBudget(t *testing.T) {
	if _, e := New(0); e == nil {
		t.Fatal("zero accepted")
	}
	l, _ := New(time.Millisecond)
	finished := make(chan struct{})
	ch := l.Start("slow", func(ctx context.Context) (string, error) { <-ctx.Done(); close(finished); return "", ctx.Err() })
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, e := Await(ctx, ch); !errors.Is(e, context.DeadlineExceeded) {
		t.Fatal(e)
	}
	select {
	case <-finished:
	default:
		t.Fatal("waiter expired but the shared loader did not stop")
	}
}
