package main

import (
	"fmt"
	"sync"
	"testing"
)

func TestLostUpdateFixture(t *testing.T) {
	if n := LostUpdate(); n != 1 {
		t.Fatalf("controlled lost-update fixture = %d", n)
	}
}
func TestCompleteIncrement(t *testing.T) {
	var c Counter
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 100 {
				c.Add(1)
			}
		}()
	}
	wg.Wait()
	if c.Load() != 800 {
		t.Fatalf("lost complete increments: %d", c.Load())
	}
}
func TestReserveBoundary(t *testing.T) {
	c := &Counter{value: 5}
	if c.TryReserve(0) || c.TryReserve(-1) || c.TryReserve(6) {
		t.Fatal("invalid reservation accepted")
	}
	if !c.TryReserve(5) || c.Load() != 0 {
		t.Fatal("exact stock must be reservable")
	}
	if c.TryReserve(1) {
		t.Fatal("oversold stock")
	}
}
func TestConcurrentReservations(t *testing.T) {
	c := &Counter{value: 7}
	accepted := make(chan bool, 40)
	var wg sync.WaitGroup
	for range 40 {
		wg.Add(1)
		go func() { defer wg.Done(); accepted <- c.TryReserve(1) }()
	}
	wg.Wait()
	close(accepted)
	n := 0
	for ok := range accepted {
		if ok {
			n++
		}
	}
	if n != 7 || c.Load() != 0 {
		t.Fatalf("reservation invariant: accepted=%d remaining=%d", n, c.Load())
	}
}
func TestSnapshotOwnership(t *testing.T) {
	input := map[string]int{"limit": 10}
	s := NewConfigStore(input)
	input["limit"] = 11
	if s.Snapshot()["limit"] != 10 {
		t.Fatal("constructor retained caller map")
	}
	view := s.Snapshot()
	view["limit"] = 99
	if s.Snapshot()["limit"] != 10 {
		t.Fatal("snapshot leaked mutable ownership")
	}
}
func TestSnapshotPair(t *testing.T) {
	s := NewConfigStore(map[string]int{"version": 0, "limit": 0})
	var wg sync.WaitGroup
	errs := make(chan string, 4)
	for range 4 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 200 {
				v := s.Snapshot()
				if v["limit"] != 10*v["version"] {
					errs <- fmt.Sprint(v)
					return
				}
			}
		}()
	}
	for i := 1; i <= 100; i++ {
		s.Update(map[string]int{"version": i, "limit": 10 * i})
	}
	wg.Wait()
	close(errs)
	for e := range errs {
		t.Fatalf("mixed snapshot: %s", e)
	}
}
func TestConcurrentWritersPreserveUpdates(t *testing.T) {
	var s ConfigStore
	var wg sync.WaitGroup
	for i := range 40 {
		wg.Add(1)
		go func(i int) { defer wg.Done(); s.Update(map[string]int{fmt.Sprint(i): i}) }(i)
	}
	wg.Wait()
	if len(s.Snapshot()) != 40 {
		t.Fatal("lost writer patch")
	}
}
