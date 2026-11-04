package cachelab

import (
	"context"
	"errors"
	"golang.org/x/sync/singleflight"
	"time"
)

type Loader struct {
	group  singleflight.Group
	budget time.Duration
}

func New(budget time.Duration) (*Loader, error) {
	if budget <= 0 {
		return nil, errors.New("positive loader budget required")
	}
	return &Loader{budget: budget}, nil
}

// Start coalesces only within this Loader instance and process. It does not
// store results, impose Redis semantics, or bound distinct-key concurrency.
func (l *Loader) Start(key string, fn func(context.Context) (string, error)) <-chan singleflight.Result {
	return l.group.DoChan(key, func() (any, error) {
		ctx, cancel := context.WithTimeout(context.Background(), l.budget)
		defer cancel()
		return fn(ctx)
	})
}
func Await(ctx context.Context, ch <-chan singleflight.Result) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case r := <-ch:
		if r.Err != nil {
			return "", r.Err
		}
		return r.Val.(string), nil
	}
}
