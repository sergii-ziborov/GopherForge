package main

import (
	"context"
	"fmt"
	"time"
	_ "time/tzdata"
)

// NextDay keeps the local calendar time under the location's rules.
// It is not a scheduler policy for missing/repeated civil times.
func NextDay(t time.Time) time.Time { return t.AddDate(0, 0, 1) }
func Wait(ctx context.Context, d time.Duration) bool {
	if ctx.Err() != nil {
		return false
	}
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}
func main() {
	loc, err := time.LoadLocation("Europe/Zurich")
	if err != nil {
		panic(err)
	}
	for _, date := range []time.Time{time.Date(2026, 3, 28, 12, 0, 0, 0, loc), time.Date(2026, 10, 24, 12, 0, 0, 0, loc)} {
		calendar, elapsed := NextDay(date), date.Add(24*time.Hour)
		fmt.Printf("start: %s\ncalendar: %s; elapsed=%s\n24 hours: %s\n", date.Format(time.RFC3339), calendar.Format(time.RFC3339), calendar.Sub(date), elapsed.Format(time.RFC3339))
	}
	a := time.Date(2026, 10, 4, 10, 0, 0, 0, time.UTC)
	b := a.In(time.FixedZone("display", 2*60*60))
	fmt.Printf("same instant: Equal=%v operator==%v\n", a.Equal(b), a == b)
	for _, stamp := range []string{"2026-10-04T10:00:00Z", "2026-10-04T12:00:00+02:00"} {
		v, e := time.Parse(time.RFC3339, stamp)
		fmt.Printf("parse %s: UTC=%s error=%v\n", stamp, v.UTC().Format(time.RFC3339), e)
	}
	now := time.Now()
	stripped := now.Round(0)
	fmt.Printf("Round(0): Equal=%v\n", now.Equal(stripped))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	fmt.Printf("pre-cancelled wait completed=%v\n", Wait(ctx, time.Hour))
}
