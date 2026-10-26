package backpressure

import (
	"context"
	"net/http"
	"time"
)

// Limit bounds simultaneous calls to next. It creates no application wait queue.
// Construct it once, then reuse the returned handler for all requests.
func Limit(max int, next http.Handler) http.Handler {
	if max < 1 || next == nil {
		panic("Limit needs a positive capacity and a handler")
	}
	slots := make(chan struct{}, max)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Context().Err() != nil {
			return
		}
		select {
		case slots <- struct{}{}:
			defer func() { <-slots }()
		default:
			w.Header().Set("Retry-After", "1")
			http.Error(w, "service busy", http.StatusServiceUnavailable)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// WithBudget propagates one handler-work budget. It does not interrupt a
// non-cooperating handler or impose a socket write deadline.
func WithBudget(budget time.Duration, next http.Handler) http.Handler {
	if budget <= 0 || next == nil {
		panic("WithBudget needs a positive duration and a handler")
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), budget)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
