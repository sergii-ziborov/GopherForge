package main

import (
	"errors"
	"fmt"
	"sync"
)

var ErrConflict = errors.New("key reused with different operation input")
var ErrReplyLost = errors.New("reply lost: caller has an unknown outcome")
var ErrCapacity = errors.New("lab capacity reached")

type Request struct {
	Job   string
	Units int
}
type Receipt struct {
	ID, Total int
	Replayed  bool
}
type record struct {
	request Request
	receipt Receipt
}
type Store struct {
	mu      sync.Mutex
	records map[string]record
	total   int
}

func (s *Store) Execute(key string, req Request) (Receipt, error) {
	if len(key) == 0 || len(key) > 128 || len(req.Job) == 0 || len(req.Job) > 128 || req.Units <= 0 || req.Units > 1000000 {
		return Receipt{}, errors.New("invalid input")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if old, ok := s.records[key]; ok {
		if old.request != req {
			return Receipt{}, ErrConflict
		}
		replay := old.receipt
		replay.Replayed = true
		return replay, nil
	}
	if len(s.records) >= 64 || req.Units > 1000000-s.total {
		return Receipt{}, ErrCapacity
	}
	if s.records == nil {
		s.records = make(map[string]record)
	}
	s.total += req.Units
	res := Receipt{ID: len(s.records) + 1, Total: s.total}
	// Effect and receipt share this in-process critical section. This is NOT
	// durable storage or a transaction spanning a separate external service.
	s.records[key] = record{request: req, receipt: res}
	return res, nil
}
func (s *Store) Total() int { s.mu.Lock(); defer s.mu.Unlock(); return s.total }
func (s *Store) Find(key string) (Receipt, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.records[key]
	return r.receipt, ok
}
func LoseReply(s *Store, key string, req Request, drop bool) (Receipt, error) {
	r, err := s.Execute(key, req)
	if err != nil {
		return Receipt{}, err
	}
	if drop {
		return Receipt{}, ErrReplyLost
	}
	return r, nil
}
func main() {
	req := Request{Job: "convert-document", Units: 7}
	naive := 0
	naive += req.Units
	naive += req.Units
	fmt.Printf("naive effect after lost reply and retry: %d\n", naive)
	var s Store
	_, err := LoseReply(&s, "operation-1", req, true)
	fmt.Printf("first response: %v; actual stored total=%d\n", err, s.Total())
	r, err := LoseReply(&s, "operation-1", req, false)
	fmt.Printf("same key: id=%d receipt-total=%d replayed=%v error=%v\n", r.ID, r.Total, r.Replayed, err)
	_, err = s.Execute("operation-1", Request{Job: req.Job, Units: 8})
	fmt.Printf("changed input: conflict=%v total=%d\n", errors.Is(err, ErrConflict), s.Total())
	r, err = s.Execute("operation-2", req)
	fmt.Printf("new key declares another operation: id=%d total=%d error=%v\n", r.ID, s.Total(), err)
	original, ok := s.Find("operation-1")
	fmt.Printf("original receipt after later work: found=%v total-at-original-commit=%d\n", ok, original.Total)
}
