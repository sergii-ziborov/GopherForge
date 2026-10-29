package examples

import (
	"context"
	"testing"
	"testing/synctest"
	"time"
)

func TestDelayedBoundary(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		out := delayed(ctx, 5*time.Second)
		assertEmpty := func() {
			t.Helper()
			select {
			case v, ok := <-out:
				t.Fatalf("early result: %q open=%v", v, ok)
			default:
			}
		}
		synctest.Wait()
		assertEmpty()
		time.Sleep(5*time.Second - time.Nanosecond)
		synctest.Wait()
		assertEmpty()
		time.Sleep(time.Nanosecond)
		synctest.Wait()
		if v, ok := <-out; !ok || v != "ready" {
			t.Fatalf("result=%q open=%v", v, ok)
		}
		if _, ok := <-out; ok {
			t.Fatal("extra result")
		}
	})
}

func TestDelayedCancellation(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		out := delayed(ctx, time.Hour)
		synctest.Wait()
		cancel()
		synctest.Wait()
		if v, ok := <-out; ok {
			t.Fatalf("notification after cancellation: %q", v)
		}
	})
}
