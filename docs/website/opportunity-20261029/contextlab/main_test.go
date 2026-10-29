package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"testing/synctest"
	"time"
)

func TestParentDeadlineCannotBeExtended(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		parent, stop := context.WithTimeout(context.Background(), 10*time.Millisecond)
		defer stop()
		child, cancel := Dependency(parent, time.Hour)
		defer cancel()
		pd, _ := parent.Deadline()
		cd, _ := child.Deadline()
		if !pd.Equal(cd) {
			t.Fatal("child extended parent deadline")
		}
		time.Sleep(10 * time.Millisecond)
		synctest.Wait()
		if !errors.Is(Stage(child, "upstream", nil), context.DeadlineExceeded) {
			t.Fatal("deadline identity lost")
		}
	})
}
func TestLocalBudgetCauseAndParentIsolation(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		parent, stop := context.WithTimeout(context.Background(), time.Hour)
		defer stop()
		child, cancel := Dependency(parent, 3*time.Second)
		defer cancel()
		time.Sleep(3 * time.Second)
		synctest.Wait()
		if parent.Err() != nil {
			t.Fatal("child canceled parent")
		}
		if !errors.Is(child.Err(), context.DeadlineExceeded) || !errors.Is(context.Cause(child), ErrDependencyBudget) {
			t.Fatal(child.Err(), context.Cause(child))
		}
	})
}
func TestCancelIsNotCompletion(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		cleanup := make(chan struct{})
		done := Launch(ctx, nil, cleanup)
		cancel()
		synctest.Wait()
		select {
		case <-done:
			t.Fatal("completed before cleanup release")
		default:
		}
		close(cleanup)
		if !errors.Is(<-done, context.Canceled) {
			t.Fatal("cancel identity lost")
		}
	})
}
func TestAlreadyCanceledAndSuccess(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	closed := make(chan struct{})
	close(closed)
	if !errors.Is(Stage(ctx, "expired", closed), context.Canceled) {
		t.Fatal("already canceled stage should not start")
	}
	if err := Stage(context.Background(), "ready", closed); err != nil {
		t.Fatal(err)
	}
}

type waitTransport struct{}

func (waitTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	<-r.Context().Done()
	return nil, r.Context().Err()
}
func TestClientTimeoutWithoutParentCancellation(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), time.Hour)
		defer cancel()
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://synthetic.invalid/items", nil)
		if err != nil {
			t.Fatal(err)
		}
		c := http.Client{Transport: waitTransport{}, Timeout: 2 * time.Second}
		_, err = c.Do(req)
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatal(err)
		}
		if ctx.Err() != nil {
			t.Fatal("client timeout unexpectedly canceled caller context")
		}
	})
}

type readyTransport struct{}

func (readyTransport) RoundTrip(*http.Request) (*http.Response, error) {
	return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader("ok"))}, nil
}
func TestImmediateSyntheticHTTPResponse(t *testing.T) {
	c := http.Client{Transport: readyTransport{}, Timeout: time.Second}
	resp, err := c.Get("http://synthetic.invalid/")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	if err != nil || string(b) != "ok" {
		t.Fatal(string(b), err)
	}
}
