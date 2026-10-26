package backpressure

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func await(t *testing.T, ch <-chan struct{}) {
	t.Helper()
	select {
	case <-ch:
	case <-time.After(2 * time.Second):
		t.Fatal("handler did not reach the expected state")
	}
}

func TestRejectAndRecoverAfterCancellation(t *testing.T) {
	entered := make(chan struct{}, 1)
	finished := make(chan struct{})
	h := Limit(1, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		entered <- struct{}{}
		<-r.Context().Done()
	}))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/", nil).WithContext(ctx))
		close(finished)
	}()
	await(t, entered)
	busy := httptest.NewRecorder()
	h.ServeHTTP(busy, httptest.NewRequest("GET", "/", nil))
	if busy.Code != http.StatusServiceUnavailable || busy.Header().Get("Retry-After") != "1" {
		t.Fatalf("overload response: %d %v", busy.Code, busy.Header())
	}
	cancel()
	await(t, finished) // Joining proves the defer released the slot.
	nextCtx, nextCancel := context.WithCancel(context.Background())
	defer nextCancel()
	nextDone := make(chan struct{})
	go func() {
		h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/", nil).WithContext(nextCtx))
		close(nextDone)
	}()
	await(t, entered) // It got through the same shared limiter.
	nextCancel()
	await(t, nextDone)
}

func TestConcurrentBound(t *testing.T) {
	const capacity = 4
	entered := make(chan struct{}, capacity)
	release := make(chan struct{})
	defer close(release)
	var active, peak atomic.Int32
	h := Limit(capacity, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := active.Add(1)
		defer active.Add(-1)
		for old := peak.Load(); n > old; old = peak.Load() {
			if peak.CompareAndSwap(old, n) {
				break
			}
		}
		entered <- struct{}{}
		select {
		case <-release:
		case <-r.Context().Done():
		}
	}))
	var workers sync.WaitGroup
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	for range capacity {
		workers.Add(1)
		go func() {
			defer workers.Done()
			h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/", nil).WithContext(ctx))
		}()
	}
	for range capacity {
		await(t, entered)
	}
	for range 20 {
		r := httptest.NewRecorder()
		h.ServeHTTP(r, httptest.NewRequest("GET", "/", nil))
		if r.Code != http.StatusServiceUnavailable {
			t.Fatalf("got %d while all slots are held", r.Code)
		}
	}
	cancel()
	workers.Wait()
	if active.Load() != 0 || peak.Load() != capacity {
		t.Fatalf("active=%d peak=%d", active.Load(), peak.Load())
	}
}

func TestBudgetAndValidation(t *testing.T) {
	var calls atomic.Int32
	lookup := func(ctx context.Context, id string) (Quote, error) {
		calls.Add(1)
		<-ctx.Done()
		return Quote{}, ctx.Err()
	}
	h := WithBudget(25*time.Millisecond, Limit(1, QuoteHandler(lookup)))
	for _, tc := range []struct {
		method, target string
		status         int
	}{
		{"POST", "/quote?id=a", http.StatusMethodNotAllowed},
		{"GET", "/quote", http.StatusBadRequest},
		{"GET", "/quote?id=a", http.StatusGatewayTimeout},
		{"GET", "/quote?id=b", http.StatusGatewayTimeout},
	} {
		w := httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest(tc.method, tc.target, nil))
		if w.Code != tc.status {
			t.Fatalf("%s: got %d want %d", tc.target, w.Code, tc.status)
		}
	}
	if calls.Load() != 2 {
		t.Fatalf("lookup calls: %d", calls.Load())
	}
}

func TestEarlierParentDeadlineWins(t *testing.T) {
	parent, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
	defer cancel()
	w := httptest.NewRecorder()
	var called bool
	h := WithBudget(time.Hour, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		if !errors.Is(r.Context().Err(), context.DeadlineExceeded) {
			t.Error("extended an expired caller deadline")
		}
	}))
	h.ServeHTTP(w, httptest.NewRequest("GET", "/", nil).WithContext(parent))
	if !called {
		t.Fatal("budget wrapper did not invoke next")
	}
	called = false
	w = httptest.NewRecorder()
	h = WithBudget(time.Hour, Limit(1, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
	})))
	h.ServeHTTP(w, httptest.NewRequest("GET", "/", nil).WithContext(parent))
	if called || w.Code != http.StatusGatewayTimeout {
		t.Fatalf("expired admission: called=%v status=%d", called, w.Code)
	}
}
