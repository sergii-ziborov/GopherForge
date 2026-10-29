package main

import (
	"context"
	"testing"
	"testing/synctest"
	"time"
)

func TestCalendarAcrossDST(t *testing.T) {
	loc, e := time.LoadLocation("Europe/Zurich")
	if e != nil {
		t.Fatal(e)
	}
	for _, tc := range []struct {
		month time.Month
		day   int
		hours time.Duration
	}{{time.March, 28, 23}, {time.October, 24, 25}} {
		start := time.Date(2026, tc.month, tc.day, 12, 0, 0, 0, loc)
		next := NextDay(start)
		if next.Hour() != 12 || next.Sub(start) != tc.hours*time.Hour {
			t.Fatalf("calendar contract: start=%v next=%v elapsed=%s", start, next, next.Sub(start))
		}
		if start.Add(24*time.Hour).Hour() == 12 {
			t.Fatal("fixture did not cross offset transition")
		}
	}
}
func TestInstantVersusRepresentation(t *testing.T) {
	a := time.Date(2026, 10, 4, 10, 0, 0, 0, time.UTC)
	b := a.In(time.FixedZone("display", 7200))
	if !a.Equal(b) || a == b {
		t.Fatal("instant/representation distinction missing")
	}
	for _, s := range []string{"2026-10-04T10:00:00Z", "2026-10-04T12:00:00+02:00"} {
		v, e := time.Parse(time.RFC3339, s)
		if e != nil || !v.Equal(a) {
			t.Fatalf("offset parse: %v %v", v, e)
		}
	}
	now := time.Now()
	if !now.Equal(now.Round(0)) {
		t.Fatal("stripping metadata changed instant")
	}
}
func TestWaitTimer(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		start := time.Now()
		if !Wait(context.Background(), 5*time.Second) {
			t.Fatal("timer did not complete")
		}
		if time.Since(start) != 5*time.Second {
			t.Fatal("wrong fake duration")
		}
	})
}
func TestWaitCancellationAndJoin(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		done := make(chan bool, 1)
		go func() { done <- Wait(ctx, time.Hour) }()
		synctest.Wait()
		cancel()
		synctest.Wait()
		select {
		case fired := <-done:
			if fired {
				t.Fatal("timer completed after cancellation")
			}
		default:
			t.Fatal("worker did not join")
		}
	})
}
func TestAlreadyCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if Wait(ctx, time.Hour) {
		t.Fatal("cancelled work admitted")
	}
}
