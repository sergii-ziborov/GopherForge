package main

import (
	"errors"
	"fmt"
	"sync"
	"testing"
)

func TestLostReplyReconciliation(t *testing.T) {
	var s Store
	req := Request{Job: "job", Units: 7}
	_, e := LoseReply(&s, "stable-key", req, true)
	if !errors.Is(e, ErrReplyLost) {
		t.Fatalf("missing lost reply: %v", e)
	}
	if r, ok := s.Find("stable-key"); !ok || r.Total != 7 || s.Total() != 7 {
		t.Fatal("effect and receipt missing after lost reply")
	}
	r, e := LoseReply(&s, "stable-key", req, false)
	if e != nil || !r.Replayed || r.Total != 7 || s.Total() != 7 {
		t.Fatalf("duplicate effect on retry: %+v %v total=%d", r, e, s.Total())
	}
}
func TestChangedInputConflict(t *testing.T) {
	var s Store
	_, _ = s.Execute("key", Request{"job", 7})
	for _, req := range []Request{{"job", 8}, {"another", 7}} {
		if _, e := s.Execute("key", req); !errors.Is(e, ErrConflict) {
			t.Fatal("changed input did not conflict")
		}
	}
	if s.Total() != 7 {
		t.Fatal("conflict changed state")
	}
}
func TestConcurrentDuplicateEffect(t *testing.T) {
	var s Store
	var wg sync.WaitGroup
	out := make(chan Receipt, 64)
	errs := make(chan error, 64)
	for range 64 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, e := s.Execute("one-key", Request{"job", 7})
			out <- r
			if e != nil {
				errs <- e
			}
		}()
	}
	wg.Wait()
	close(out)
	close(errs)
	for e := range errs {
		t.Fatal(e)
	}
	first := 0
	for r := range out {
		if r.ID != 1 || r.Total != 7 {
			t.Fatalf("different replay receipt: %+v", r)
		}
		if !r.Replayed {
			first++
		}
	}
	if first != 1 || s.Total() != 7 {
		t.Fatalf("duplicate effects: first=%d total=%d", first, s.Total())
	}
}
func TestHistoricalReceiptAndNewKey(t *testing.T) {
	var s Store
	r, _ := s.Execute("first", Request{"job", 7})
	later, _ := s.Execute("second", Request{"job", 7})
	again, _ := s.Execute("first", Request{"job", 7})
	if r.ID == later.ID || s.Total() != 14 || again.Total != 7 || !again.Replayed {
		t.Fatal("historical receipt or new-key contract changed")
	}
}
func TestLimitsAndReplayAtCapacity(t *testing.T) {
	var s Store
	for i := range 64 {
		if _, e := s.Execute(fmt.Sprint(i), Request{"job", 1}); e != nil {
			t.Fatal(e)
		}
	}
	if _, e := s.Execute("new", Request{"job", 1}); !errors.Is(e, ErrCapacity) {
		t.Fatal("ledger capacity ignored")
	}
	if r, e := s.Execute("0", Request{"job", 1}); e != nil || !r.Replayed {
		t.Fatal("capacity blocked existing replay")
	}
	var total Store
	if _, e := total.Execute("max", Request{"job", 1000000}); e != nil {
		t.Fatal(e)
	}
	if _, e := total.Execute("overflow", Request{"job", 1}); !errors.Is(e, ErrCapacity) {
		t.Fatal("unit capacity ignored")
	}
	if _, e := total.Execute("max", Request{"job", 1000000}); e != nil {
		t.Fatal("total capacity blocked replay")
	}
}
func TestInvalidInputDoesNotCommit(t *testing.T) {
	var s Store
	for _, req := range []Request{{"", 1}, {"job", 0}, {"job", -1}, {"job", 1000001}} {
		if _, e := s.Execute("key", req); e == nil {
			t.Fatal("invalid request accepted")
		}
	}
	if _, e := s.Execute("", Request{"job", 1}); e == nil {
		t.Fatal("empty key accepted")
	}
	if s.Total() != 0 {
		t.Fatal("validation changed total")
	}
}
