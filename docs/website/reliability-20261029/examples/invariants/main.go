package main

import (
	"fmt"
	"sync"
	"sync/atomic"
)

type Counter struct {
	mu    sync.Mutex
	value int
}

func (c *Counter) Load() int   { c.mu.Lock(); defer c.mu.Unlock(); return c.value }
func (c *Counter) Store(n int) { c.mu.Lock(); defer c.mu.Unlock(); c.value = n }
func (c *Counter) Add(n int)   { c.mu.Lock(); defer c.mu.Unlock(); c.value += n }
func (c *Counter) TryReserve(n int) bool {
	if n <= 0 {
		return false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if n > c.value {
		return false
	}
	c.value -= n
	return true
}

// LostUpdate deliberately separates synchronized reads from synchronized writes.
// The barrier ensures both readers observe zero before either writes.
func LostUpdate() int {
	var c Counter
	seen := make(chan struct{}, 2)
	release := make(chan struct{})
	var wg sync.WaitGroup
	for range 2 {
		wg.Add(1)
		go func() { defer wg.Done(); v := c.Load(); seen <- struct{}{}; <-release; c.Store(v + 1) }()
	}
	<-seen
	<-seen
	close(release)
	wg.Wait()
	return c.Load()
}

type config struct{ rates map[string]int }
type ConfigStore struct {
	writers sync.Mutex
	active  atomic.Pointer[config]
}

func clone(in map[string]int) map[string]int {
	out := make(map[string]int, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}
func NewConfigStore(initial map[string]int) *ConfigStore {
	s := &ConfigStore{}
	s.Update(initial)
	return s
}

// Update publishes one complete new version. Callers must not mutate patch during this call.
func (s *ConfigStore) Update(patch map[string]int) {
	s.writers.Lock()
	defer s.writers.Unlock()
	next := map[string]int{}
	if old := s.active.Load(); old != nil {
		next = clone(old.rates)
	}
	for k, v := range patch {
		next[k] = v
	}
	s.active.Store(&config{rates: next})
}

// Snapshot returns independent map storage. Values are ints; nested mutable values
// would require their own ownership policy, not just this outer-map copy.
func (s *ConfigStore) Snapshot() map[string]int {
	v := s.active.Load()
	if v == nil {
		return map[string]int{}
	}
	return clone(v.rates)
}
func main() {
	fmt.Printf("two synchronized read-then-write increments: %d\n", LostUpdate())
	var correct Counter
	var wg sync.WaitGroup
	for range 2 {
		wg.Add(1)
		go func() { defer wg.Done(); correct.Add(1) }()
	}
	wg.Wait()
	fmt.Printf("two complete Add operations: %d\n", correct.Load())
	stock := &Counter{value: 5}
	fmt.Printf("reserve exact stock: %v; remaining=%d\n", stock.TryReserve(5), stock.Load())
	input := map[string]int{"version": 1, "limit": 10}
	s := NewConfigStore(input)
	input["limit"] = 999
	view := s.Snapshot()
	view["limit"] = 888
	fmt.Printf("after caller mutations: limit=%d\n", s.Snapshot()["limit"])
	s.Update(map[string]int{"version": 2, "limit": 20})
	v := s.Snapshot()
	fmt.Printf("published pair: version=%d limit=%d\n", v["version"], v["limit"])
}
