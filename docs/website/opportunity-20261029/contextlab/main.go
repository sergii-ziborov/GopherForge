package main

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var ErrDependencyBudget = errors.New("synthetic dependency budget")

// Stage waits for one explicit event or cancellation. A nil gate waits only
// for cancellation. Callers must supply a non-nil Context.
func Stage(ctx context.Context, name string, gate <-chan struct{}) error {
	if err := ctx.Err(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	select {
	case <-gate:
		return nil
	case <-ctx.Done():
		return fmt.Errorf("%s: %w", name, ctx.Err())
	}
}

// Dependency preserves the parent's earlier deadline and records a local cause.
func Dependency(parent context.Context, budget time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeoutCause(parent, budget, ErrDependencyBudget)
}

// Launch simulates work followed by an explicitly controlled cleanup stage.
// The owner releases cleanup and receives done to observe actual completion.
func Launch(ctx context.Context, gate, cleanup <-chan struct{}) <-chan error {
	done := make(chan error, 1)
	go func() {
		err := Stage(ctx, "worker", gate)
		<-cleanup
		done <- err
		close(done)
	}()
	return done
}
func main() {
	expired, cancel := context.WithDeadlineCause(context.Background(), time.Now().Add(-time.Second), ErrDependencyBudget)
	defer cancel()
	err := Stage(expired, "database", nil)
	fmt.Printf("stage error matches deadline: %v; named cause: %v\n", errors.Is(err, context.DeadlineExceeded), errors.Is(context.Cause(expired), ErrDependencyBudget))
	parent, stop := context.WithCancel(context.Background())
	cleanup := make(chan struct{})
	done := Launch(parent, nil, cleanup)
	stop()
	close(cleanup)
	fmt.Printf("joined worker matches cancellation: %v\n", errors.Is(<-done, context.Canceled))
}
